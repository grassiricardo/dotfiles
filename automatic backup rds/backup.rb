require 'dotenv'
require 'yaml'
require 'aws-sdk-s3'

config = YAML.load_file('config.yml')

# Backup databases to .dump files
backuped_files = []
config['databases'].each do |dbname|
  timestamp = Time.now.strftime('%Y%m%d%H%M%S%L')
  backup_file = "#{dbname}_#{timestamp}.sql"

  cmd = "PGPASSWORD=#{config['postgres']['password']} pg_dump --no-owner"
  cmd += " -h #{config['postgres']['host']}"
  cmd += " --user=#{config['postgres']['username']}"
  cmd += " #{dbname} > tmp/#{backup_file}"

  system(cmd)
  backuped_files << backup_file
end

compressed_files = []
backuped_files.each do |bkp_file|
  # Generate compressed file
  db_name = bkp_file.split('_')[0]
  zipfile_name = "#{db_name}_#{Time.now.strftime('%Y%m%d%H%M%S')}.tar.gz"
  zip_command = "cd tmp && tar -czvf #{zipfile_name} #{bkp_file}"
  system(zip_command)

  compressed_files << zipfile_name
end

# Upload backups to S3
compressed_files.each do |comp_file|
  file = open("tmp/#{comp_file}")

  s3 = Aws::S3::Resource.new(
    region: config['aws']['region'],
    access_key_id: config['aws']['access_key_id'],
    secret_access_key: config['aws']['secret_access_key']
  )
  obj = s3.bucket(config['aws']['bucket']).object(comp_file)
  send_message_to_slack(comp_file) if obj.upload_file(file)
end

def send_message_to_slack(filename)
  payload = {
    channel: config['slack']['channel'],
    text: "Backup #{filename} finalized with successful"
  }.to_json

  cmd = 'curl -X POST --data-urlencode '
  cmd += "'payload=#{payload}' #{config['slack']['webhook']}"
  system(cmd)
end

# Delete Files
backuped_files.map { |f| system("rm tmp/#{f}") }
compressed_files.map { |f| system("rm tmp/#{f}") }

puts 'Backup finished'
