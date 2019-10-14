control 'container' do
  impact 0.5
  describe docker_container('mysql-server') do
    it { should exist }
    it { should be_running }
    its('repo') { should eq 'mysql/mysql-server' }
    its('ports') { should eq '3306/tcp' }
    its('command') { should match '/entrypoint.sh mysqld' }
  end
end
control 'server-package' do
  impact 0.5
  describe package('mysql-community-server-minimal') do
    it { should be_installed }
    its ('version') { should match '5.6.46.*' }
  end
end
