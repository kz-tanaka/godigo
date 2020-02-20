require 'open3'
require 'godigo/cui'
module Godigo::Commands
  class SessionCommand < Godigo::Cui
    def option_parser
      opts = OptionParser.new do |opt|
      opt.banner = <<-"EOS".unindent
NAME
  #{program_name} - Keep track of machine status

SYNOPSIS
  #{program_name} action [options...]

DESCRIPTION
  Keep track of machine status.  This also offers interface for
  synchronization.  Action can be `start', `stop', and `sync'.
  Machine and machine-server should be specified in a configuration
  file `~/.godigorc' as inferred later.  Note that for each action,
  dedicated application is prepared to be invoked from MS Windows.

  start
    Start `machine' on machine-server to log status.  To
    invoke #{program_name}-start does the same thing.

  stop
    Stop `mach-in' on machine-server to log status and issue `sync'.
    To invoke #{program_name}-stop does the same thing.

  sync
    Synchronize local directory to remote directory specified in a
    configuration file.  The action invokes `rsync' as sub-process
    when parameters `src_path' and `dst_path' are found in the
    configuration file.  To invoke #{program_name}-sync does the same
    thing.  Options involved are shown below.
    $ cd ${src_path} && rsync -rltgoDvh --delete -e ssh ./* ${dst_path}

TROUBLESHOOT
    Time to time, you see error messages as shown below.

      rsync: recv_generator: mkdir "/backup/JSM-7001F-LV/sync/..." failed: Permission denied (13)
      rsync: recv_generator: failed to stat "/backup/JSM-7001F...": Permission denied (13)

    This is resulted from wrong permission of a certain directory of
    the backup server.  It is not clear how that happens.  See
    following example to fix the permission.

      $ ssh falcon@archive.misasa.okayama-u.ac.jp
      archive$ cd /backup/JSM-7001F-LV/sync/
      archive$ chmod a+rwx -R *

SETUP FOR SYNC
  (1) On Windows, mount a source directory with proper volume name
      such as "U:/".  On the top directory, place a file
      `checkpoint.org' with any content for file recognition.
  (2) Make sure if rsync in installed somewhere discoverable.  In a
      case of Windows, to use rsync on Cygwin is recommended.
  (3) Find out how the directory is spelled.  For a case where volume
      "U:/" on Windows is the source, the directory should be referred
      as "/cygdrive/u/" for rsync on Cygwin.  Place it on :src_path:
      of the configuration file.
  (4) Create a directory in a server with proper permission.  Place
      the ssh-based URL onto :dst_path: in the configuration file.
  (5) Setup ssh key to access to the server without authorization.

EXAMPLE OF CONFIGURATION FILE
  ## machine config
  uri_machine: database.misasa.okayama-u.ac.jp/machine
  machine: JSM-7001F-LV
  ## sync config
  src_path: /cygdrive/u/
  dst_path: falcon@archive.misasa.okayama-u.ac.jp:/backup/JSM-7001F-LV/sync/
  #rsync_path: /usr/bin/rsync

SEE ALSO
  http://dream.misasa.okayama-u.ac.jp
  TimeBokan
  rsync
  https://github.com/misasa/godigo/blob/master/lib/godigo/commands/session_command.rb

IMPLEMENTATION
  Orochi, version 9
  Copyright (C) 2015-2020 Okayama University
  License GPLv3+: GNU GPL version 3 or later

HISTORY
  October 4, 2018: Support src_path with drive letter
  October 1, 2018: Change strategy for sync to support MSYS
  October 3, 2017: Add a section trouble shoot.
  July 15, 2016: Change option for rsync from `-avh' to `-rltgoDvh'
  April 26, 2016: Documentation updated to be more correct
  February 1, 2016: Revise document by Tak Kunihiro
  October 1, 2015: Documented by Tak Kunihiro

OPTIONS
EOS
      opt.on("-v", "--[no-]verbose", "Run verbosely") {|v| OPTS[:verbose] = v}
      opt.on("-m", "--message", "Add information on start") {|v| OPTS[:message] = v}
      opt.on("-o", "--open", "Open by web browser") {|v| OPTS[:web] = v}
      end
      opts
    end

    def get_machine
      MachineTimeClient::Machine.instance
    end

    def open_browser
      machine = get_machine
      url = "http://database.misasa.okayama-u.ac.jp/machine/machines/#{machine.id}"
      if RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin/
      system("start #{url}")
      elsif RUBY_PLATFORM.downcase =~ /cygwin/
      system("cygstart #{url}")
      elsif RUBY_PLATFORM.downcase =~ /darwin/
      system("open #{url}")
      else
      raise
      end
    end

    def print_label(session)
      if RUBY_PLATFORM.downcase !~ /darwin/
      cmd = "tepra print #{session.global_id},#{session.name}"
      Open3.popen3(cmd) do |stdin, stdout, stderr|
        err = stderr.read
        unless err.blank?
          p err
        end
      end
      # system("tepra-duplicate")
      # system("perl -S tepra-duplicate")
      end
    end

    def start_session
      machine = get_machine
      if machine.is_running?
      stdout.print "An open session |#{machine.name}| exists.  Do you want to close and start a new session? [Y/n] "
        answer = (stdin.gets)[0].downcase
      if answer == "y" or answer == "\n"
        machine.stop
        machine.start
      else
        exit
      end
      else
      machine.start
      end
      session = machine.current_session
      print_label session
      if OPTS[:message]
      message = argv.shift
      if message
        session.description = message
        session.save
      end
      end
      stdout.puts session if OPTS[:verbose]

      if OPTS[:web]
      open_browser
      end
    end

    def stop_session
      machine = get_machine
      if machine.is_running?
      session = machine.current_session
      stdout.puts session if OPTS[:verbose]
      machine.stop
      stdout.puts "Session closed"
      sync_session
      end
    end

    def config
      MachineTimeClient.config
    end

    def checkpoint
      _path = get_src_path.clone
        #   if RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin/
      if platform =~ /mswin(?!ce)|mingw|bccwin/ # when Ruby is on Windows-NT (mingw) not on Cygwin
      # _path = _path.gsub(/\/cygdrive\/c\/Users/,"C:/Users")
      # _path = _path.gsub!(/\//,"\\")
      # _path.gsub!("/cygdrive/c/Users","C:/Users")
      _path.gsub!("/cygdrive/c","C:")
      _path.gsub!("/cygdrive/d","d:")
      _path.gsub!("/cygdrive/e","e:")
      _path.gsub!("/cygdrive/f","F:")
      _path.gsub!("/cygdrive/g","G:")
      _path.gsub!("/cygdrive/t","T:")
      _path.gsub!("/cygdrive/u","U:")
      _path.gsub!("/cygdrive/v","V:")
      _path.gsub!("/cygdrive/x","X:")
      _path.gsub!("/cygdrive/y","Y:")
      _path.gsub!("/cygdrive/z","Z:")
      end
      File.join(_path, 'checkpoint.org')
    end

    def get_dst_path
        #    dst_path: falcon@itokawa.misasa.okayama-u.ac.jp:/home/falcon/deleteme.d
      if config.has_key?(:dst_path)
      _path = config[:dst_path]
      elsif config.has_key?('dst_path')
      _path = config['dst_path']
      end
      unless _path
      raise "Machine configuration file |#{MachineTimeClient.pref_path}| does not have parameter |dst_path|.  Put a line such like |dst_path: falcon@archive.misasa.okayama-u.ac.jp:/backup/mymachine/sync|."
      end
      _path
    end

    def get_src_path
        #    src_path: C:/Users/dream/Desktop/deleteme.d
      if config.has_key?(:src_path)
        _path = config[:src_path]
      elsif config.has_key?('src_path')
        _path = config['src_path']
      end
      unless _path
        raise "Machine configuration file |#{MachineTimeClient.pref_path}| does not have parameter |src_path|.  Put a line such like |src_path: C:/Users/dream/Desktop/deleteme.d"
      end
      _path
    end

    def checkpoint_exists?
      File.exists? checkpoint
    end

    def sync_command
      dst_path = get_dst_path
      src_path = get_src_path
      rsync_path = "rsync"
      if config.has_key?(:rsync_path)
        rsync_path = config[:rsync_path]
      end
      cmd = "cd "
      if src_path =~ /[A-Z]\:/ # when path include drive letter
        cmd += "/d #{src_path} && "
      else
        cmd = "cd #{src_path} && "
      end
      cmd = cmd + "#{rsync_path} -rltgoDvh --delete --chmod=u+rwx -e ssh ./* #{dst_path}" # -a == -rlptgoD
    end

    def sync_session
      dst_path = get_dst_path
      src_path = get_src_path
      raise "Could not find checkpoint file in #{checkpoint}." unless checkpoint_exists?
      stdout.print "Are you sure you want to copy #{src_path} to #{dst_path}? [Y/n] "
      answer = (stdin.gets)[0].downcase
      unless answer == "n"
          # cmd = "rsync -avh --delete -e ssh #{src_path} #{dst_path}"
          # cmd = "cd #{src_path} && rsync -rltgoDvh --delete -e ssh ./* #{dst_path}" # -a == -rlptgoD
          cmd = sync_command
          stdout.print "--> I issued |#{cmd}|"
          system_execute(cmd)
        end
    end

    def execute
      subcommand =  argv.shift.downcase unless argv.empty?
      if subcommand =~ /start/
        start_session
      elsif subcommand =~ /stop/
        stop_session
      elsif subcommand =~ /sync/
        sync_session
      else
      raise "invalid command!"
      end
    end
  end
end
