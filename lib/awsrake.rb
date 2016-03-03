require 'aws-sdk'


module AWSRake

  NAME = 'awsrake'

  TASKS_DIR = 'tasks'
  ALL_FILES = '**'

  RUBY_FILE_EXT = '.rb'

  def self.load_files(dir = File.join(File.dirname(File.expand_path(__FILE__)), NAME), file_ext = RUBY_FILE_EXT)
    Dir[File.join(dir, ALL_FILES, "*#{file_ext}")].reverse.each do |file|
      yield(file) if File.file?(file)
    end
  end

  def self.load_tasks(dir = Dir.pwd)
    load_files(File.join(dir, TASKS_DIR), nil) do |file|
      load file
    end
  end

  load_files do |file|
    require file
  end

end
