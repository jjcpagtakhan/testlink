#
# Cookbook: QA Testlink
#

execute 'apt-update' do
	command 'apt-get update'
	ignore_failure true
	action :run
end

execute 'daemon-reload' do
  command "systemctl daemon-reload"
  action :nothing
end

package 'docker.io'
package 'docker-compose'
package	'python-pip'

service 'docker-enable-start' do
	service_name	'docker.service'
	action	[:enable, :start]
end

execute 'install-awscli' do
	command 'pip install awscli'
end

directory '/Docker/' do
	owner	'root'
	group	'root'
	mode	'0755'
	action	:create
end

template '/Docker/docker-compose.yml' do
	source	'testlink-docker-compose.erb'
	owner	'root'
	group	'root'
	mode	'0744'
end

node['spiral']['testlinkdata'].each do |dir, path|
	directory path do
		action  :create
        	owner   '1001'
        	group   '1001'
        	mode    '0755'
	end
end

execute 'set-owner' do
	command 'chown -R 1001:1001 /testlink/*'
end

execute 'run-docker-compose' do
	cwd	'/Docker'
	command 'docker-compose up -d; sleep 330'
end

file '/testlink/mariadb/mariadb/conf/my.cnf' do
    only_if { ::File.exist?('/testlink/mariadb/mariadb/conf/my.cnf') }
    action :delete
end

template '/testlink/mariadb/mariadb/conf/my.cnf' do
        source  'testlink-mariadb.erb'
        owner   'root'
        group   'root'
        mode    '0700'
	action	:create
	notifies :run, 'execute[set-owner]', :immediately
end

template '/etc/systemd/system/testlink.service' do
        source  'testlink-service.erb'
        owner   'root'
        group   'root'
        mode    '0664'
end

template '/etc/systemd/system/mariadb.service' do
        source  'testlink-mariadb-service.erb'
        owner   'root'
        group   'root'
        mode    '0664'
end

service 'testlink-service-enable-start' do
	service_name	'testlink.service'
        action  [:enable, :start]
	notifies :run, 'execute[daemon-reload]', :immediately
end

service 'mariadb-service-enable-start' do
        service_name    'mariadb.service'
        action  [:enable, :start]
	notifies :run, 'execute[daemon-reload]', :immediately
end

#
# Testlink Backup
# Note: Please add AWS secret key and access ID to server or provide IAM role to instance to have r/w access to main backup s3 bucket
# Add script to crontab to run every 5:00 AM (UTC+8)
# 0 21 * * * /usr/bin/nice -n19 /usr/bin/ionice -n7 -c2 /opt/backup/backup.sh

directory '/opt/backup' do
        owner   'root'
        group   'root'
        mode    '0755'
        action  :create
end

directory '/testlink/mariadb/mariadb/backup' do
        owner   'root'
        group   'root'
        mode    '0755'
        action  :create
end

execute 'write-upload-area' do
	command 'chmod a+w /testlink/data/testlink/upload_area/'
end


node['backup']['testlink'].each do |dir, path|
        directory path do
                action  :create
                owner   'root'
                group   'root'
                mode    '0755'
        end
end

template '/opt/backup/backup.sh' do
        source  'testlink-backup.erb'
        owner   'root'
        group   'root'
        mode    '0644'
end

execute 'backup-executable' do
	command 'chmod a+x /opt/backup/backup.sh'
end
