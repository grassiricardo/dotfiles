require 'yaml'
require 'aws-sdk-s3'
require 'json'

config = YAML.load_file('./scripts/automatic_backup/config.yml')

payload = {
  channel: config['slack']['channel'],
  text: 'Backup started',
  icon_emoji: config['slack']['airplane_departure']
}.to_json

cmd = 'curl -X POST --data-urlencode '
cmd += "'payload=#{payload}' #{config['slack']['webhook']}"
system(cmd)

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

payload = {
  channel: config['slack']['channel'],
  text: 'Backup being comprressed',
  icon_emoji: config['slack']['airplane']
}.to_json

cmd = 'curl -X POST --data-urlencode '
cmd += "'payload=#{payload}' #{config['slack']['webhook']}"
system(cmd)

compressed_files = []
backuped_files.each do |bkp_file|
  # Generate compressed file
  db_name = bkp_file.split('_')[0]
  zipfile_name = "#{db_name}_#{Time.now.strftime('%Y%m%d%H%M%S')}.tar.gz"
  zip_command = "cd tmp && tar -czvf #{zipfile_name} #{bkp_file}"
  system(zip_command)

  compressed_files << zipfile_name
end

payload = {
  channel: config['slack']['channel'],
  text: 'Backup upload S3 started',
  icon_emoji: config['slack']['airplane']
}.to_json

cmd = 'curl -X POST --data-urlencode '
cmd += "'payload=#{payload}' #{config['slack']['webhook']}"
system(cmd)

# Upload backups to S3
compressed_files.each do |comp_file|
  file = open("tmp/#{comp_file}")

  s3 = Aws::S3::Resource.new(
    region: config['aws']['region'],
    access_key_id: config['aws']['access_key_id'],
    secret_access_key: config['aws']['secret_access_key']
  )
  obj = s3.bucket(config['aws']['bucket']).object(comp_file)
  obj.upload_file(file)
end

payload = {
  channel: config['slack']['channel'],
  text: "Backup finalized with successful",
  icon_emoji: config['slack']['airplane_arriving']
}.to_json

cmd = 'curl -X POST --data-urlencode '
cmd += "'payload=#{payload}' #{config['slack']['webhook']}"
system(cmd)

# Delete Files
backuped_files.map { |f| system("rm tmp/#{f}") }
compressed_files.map { |f| system("rm tmp/#{f}") }

puts 'Backup finished'

33 19 * * * /bin/bash -l -c 'ruby ./scripts/automatic_backup/backup.rb'