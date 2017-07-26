#!/usr/bin/env ruby

# dockerfile-generator.rb
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

require 'set'
require 'yaml'

class Dockerfile
  def initialize
    @from       = 'ubuntu'
    @user       = nil
    @service    = nil

    @maintainers  = Set.new
    @requirements = Set.new
    @packages     = Set.new
    @ports        = []
    @work_dir     = nil

    # Files to add before and after the run command
    @adds_before = []
    @adds_after  = []

    # Environment variables
    @env_vars = []

    # Command lists for the run section
    @begin_commands        = []
    @pre_install_commands  = []
    @install_commands      = []
    @post_install_commands = []
    @run_commands          = []
    @end_commands          = []

    # Command for the cmd section
    @command = nil
  end

  ##############################################################################
  public

  # string ()
  def finalize
    lines = []
    lines.push "FROM #{@from}"
    lines.push ''
    @maintainers.each { |m| lines.push "MAINTAINER #{m}" }
    lines.push '' unless @maintainers.empty?
    lines.push "USER #{@user}"
    lines.push '' unless @user.nil?
    lines += @env_vars
    lines.push '' unless @env_vars.nil?
    lines += @adds_before
    lines.push '' unless @adds_before.empty?
    lines.push build_run_command
    lines.push ''
    lines += @adds_after
    lines.push '' unless @adds_after.empty?
    lines.push "EXPOSE #{@ports.join(' ')}"
    lines.push '' unless @ports.empty?
    lines.push "WORKDIR #{@work_dir}" unless @work_dir.nil?
    lines.push '' unless @work_dir.nil?
    lines.push "CMD #{@command}" unless @command.nil?
  end

  # void (string)
  def add_maintainer(maintainer)
    @maintainers.add(maintainer)
  end

  # void (string)
  def set_user(user)
    @user = user
  end

  # void (string, string)
  def add_env_var(key, value)
    @env_vars.push "ENV #{key} #{value}"
  end

  # void (string)
  def set_from(from)
    @from = from
  end

  # void (string)
  def set_service(service)
    @service = service
  end

  # void (string, string)
  def add_before(source, destination = '/')
    @adds_before.push "ADD #{source} #{destination}"
  end

  # void (string, string)
  def add_after(source, destination = '/')
    @adds_after.push "ADD #{source} #{destination}"
  end

  # void (int)
  def expose(port)
    @ports.push port
  end

  # void (string, string, string)
  def add_repository(name, deb, key = nil)
    add_pre_install_command comment "Adding #{name} repository"
    add_pre_install_command "wget -O - #{key} | apt-key add -" if key
    add_pre_install_command "echo '#{deb}' >> /etc/apt/sources.list.d/#{name.downcase}.list"
    add_pre_install_command blank

    @requirements.add 'wget'
    @requirements.add 'ssl-cert'
  end

  # void (string, string)
  def add_ppa(name, ppa)
    add_pre_install_command comment "Adding #{name} PPA"
    add_pre_install_command "add-apt-repository -y #{ppa}"
    add_pre_install_command blank

    @requirements.add 'software-properties-common'
    @requirements.add 'python-software-properties'
  end

  # void (string)
  def install_package(package)
    @packages.add package
  end

  # void (string)
  def run(command)
    command.strip!
    if command.start_with? '#'
      add_run_command comment command[1..-1].strip
    elsif command =~ /^\s*$/
      add_run_command blank
    else
      add_run_command command
    end
  end

  # void (string)
  def set_command(command)
    @command = "['#{command.split.join("','")}']"
  end

  # void (string)
  def set_working_directory(dir)
    @work_dir = dir
  end

  ##############################################################################
  private

  # string (string)
  def comment(string)
    "`\# #{string}`"
  end

  # string ()
  def blank
    '\\'
  end

  # [string] ([string])
  def build_install_command(packages)
    # Convert the set to an array
    packages = packages.to_a

    # Specify the command
    command = 'apt-get install -y --no-install-recommends'

    # Make an array of paddings
    lines = [' ' * command.length] * packages.length

    # Overwrite the first line with the command
    lines[0] = command

    # Append the packages and backslashes to each line
    lines = lines.zip(packages).collect { |l, p| l += " #{p} \\" }

    # Convert the backslash on the last line to "&& \"
    lines[-1] = lines[-1][0..-2] + '&& \\'

    # Add comment and blank
    lines.insert(0, comment('Installing packages'))
    lines.push blank
  end

  # string ()
  def build_run_command
    lines = []

    # Any packages that were requirements can be removed from the packages list
    @packages = @packages.difference @requirements

    lines += begin_commands

    # If required packages were specified
    unless @requirements.empty?
      # Update the package list
      lines.push comment 'Updating Package List'
      lines.push 'apt-get update'
      lines.push blank

      # Install requirements
      lines += build_install_command @requirements
    end

    # Run pre-install commands
    lines += pre_install_commands

    # Install packages
    lines += build_install_command @packages unless @packages.empty?

    # Run install commands
    lines += install_commands

    # Run post-install commands
    unless @post_install_commands.empty?
      lines.push comment 'Removing temporary files'
      lines += post_install_commands
      lines.push blank
    end

    # Run commands
    lines += run_commands
    lines.push blank unless @run_commands.empty?

    # Clean up
    lines.push comment 'Cleaning up after installation'
    lines.push 'apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*'
    lines.push blank

    # Enable service on startup
    if @service
      lines.push comment 'Enable service on startup'
      lines.push "sed -i \"s@exit 0@service #{@service} start@g\" /etc/rc.local"
      lines.push blank
    end

    # End commands
    lines += end_commands

    # Determine the longest line
    longest_length = lines.max_by(&:length).length

    # For each line
    lines.collect do |l|
      # Determine how many spaces needed to indent
      length_to_extend = longest_length - l.length

      # Indent the line
      length_to_extend += 1 if l.start_with? '`'
      l.insert(0, ' ' * (l.start_with?('`') ? 4 : 5))

      # Add or Extend end markers
      if l.end_with? ' && \\'
        length_to_extend += 5
        l.insert(-6, ' ' * length_to_extend)
      elsif l.end_with? ' \\'
        length_to_extend += 5
        l.insert(-3, ' ' * length_to_extend)
      else
        l.insert(-1, ' ' * length_to_extend)
        l.insert(-1, ' && \\')
      end
    end

    # First line should start with "RUN"
    lines[0][0..2] = 'RUN'

    # Last line should not end with marker
    lines[-1].gsub! ' && \\', ''
    lines[-1].gsub! ' \\', ''

    # Last line might be blank now, do it again
    if lines[-1] =~ /^\s*$/
      lines.delete_at -1

      # Last line should not end with marker
      lines[-1].gsub! ' && \\', ''
      lines[-1].gsub! ' \\', ''
    end

    # Make a string
    lines.join "\n"
  end

  ##############################################################################

  # Some metaprogramming to handle the various command lists
  def self.handle(arg)
    class_eval("def #{arg};@#{arg};end")
    class_eval("def add_#{arg[0..-2]}(val);@#{arg}.push val;end")
  end

  handle :begin_commands
  handle :pre_install_commands
  handle :install_commands
  handle :post_install_commands
  handle :run_commands
  handle :end_commands
end

################################################################################
# Parse Dockerfile.yml

dockerfile = Dockerfile.new
yaml = YAML.load_file('Dockerfile.yml')

# Parse Maintainers tag
yaml['Maintainers'].each do |maintainer|
  dockerfile.add_maintainer maintainer
end if yaml.key? 'Maintainers'

# Parse From tag
dockerfile.set_from yaml['From'] if yaml.key? 'From'

# Parse User tag
dockerfile.set_user yaml['User'] if yaml.key? 'User'

# Parse Env tag
yaml['Env'].each do |i|
  dockerfile.add_env_var i.first[0], i.first[1]
end if yaml.key? 'Env'

# Parse Service tag
dockerfile.set_service yaml['Service'] if yaml.key? 'Service'

# Parse Add_Before tag
yaml['Add_Before'].each do |i|
  if i.is_a? Hash
    dockerfile.add_before i.first[0], i.first[1]
  else
    dockerfile.add_before i
  end
end if yaml.key? 'Add_Before'

# Parse Repositories tag
yaml['Repositories'].each do |r|
  if r['URL'].start_with? 'deb '
    dockerfile.add_repository(r['Name'], r['URL'], r['Key'])
  elsif r['URL'].start_with? 'ppa:'
    dockerfile.add_ppa(r['Name'], r['URL'])
  end
end if yaml.key? 'Repositories'

# Parse Run tag
yaml['Run'].split("\n").each do |line|
  dockerfile.run line
end if yaml.key? 'Run'

# Parse Add_After tag
yaml['Add_After'].each do |i|
  if i.is_a? Hash
    dockerfile.add_after i.first[0], i.first[1]
  else
    dockerfile.add_after i
  end
end if yaml.key? 'Add_After'

# Parse Expose tag
yaml['Expose'].each do |port|
  dockerfile.expose port
end if yaml.key? 'Expose'

# Parse Command tag
dockerfile.set_command yaml['Command'] if yaml.key? 'Command'

# Parse Work_Dir tag
dockerfile.set_working_directory yaml['Work_Dir'] if yaml.key? 'Work_Dir'

# Output Dockerfile
File.open('Dockerfile', 'w') do |f|
  f.puts dockerfile.finalize
end
