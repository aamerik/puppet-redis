require 'spec_helper'

describe 'redis::sentinel' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      let(:config_file_orig) do
        case facts[:osfamily]
        when 'Archlinux'
          '/etc/redis/redis-sentinel.conf.puppet'
        when 'Debian'
          '/etc/redis/redis-sentinel.conf.puppet'
        when 'Suse'
          '/etc/redis/redis-sentinel.conf.puppet'
        when 'FreeBSD'
          '/usr/local/etc/redis-sentinel.conf.puppet'
        when 'RedHat'
          '/etc/redis-sentinel.conf.puppet'
        end
      end

      let(:pidfile) do
        if facts[:operatingsystem] == 'Ubuntu'
          '/var/run/sentinel/redis-sentinel.pid'
        elsif facts[:operatingsystem] == 'Debian'
          facts[:operatingsystemmajrelease] == '9' ? '/var/run/redis/redis-sentinel.pid' : '/run/sentinel/redis-sentinel.pid'
        else
          '/var/run/redis/redis-sentinel.pid'
        end
      end

      let(:redis_package_name) do
        'redis'
      end

      let(:sentinel_package_name) do
        if facts[:os]['family'] == 'Debian'
          'redis-sentinel'
        else
          'redis'
        end
      end

      describe 'without parameters' do
        let(:expected_content) do
          <<CONFIG
port 26379
dir #{facts[:osfamily] == 'Debian' ? '/var/lib/redis' : '/tmp'}
daemonize #{facts[:osfamily] == 'RedHat' ? 'no' : 'yes'}
pidfile #{pidfile}
protected-mode yes

sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 30000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 180000

loglevel notice
logfile #{facts[:osfamily] == 'Debian' ? '/var/log/redis/redis-sentinel.log' : '/var/log/redis/sentinel.log'}
CONFIG
        end

        it { is_expected.to create_class('redis::sentinel') }

        it {
          is_expected.to contain_file(config_file_orig).
            with_ensure('file').
            with_mode('0644').
            with_owner('redis').
            with_content(expected_content)
        }

        it {
          is_expected.to contain_service('redis-sentinel').
            with_ensure('running').
            with_enable('true')
        }

        it { is_expected.to contain_package(sentinel_package_name).with_ensure('installed') }
      end

      describe 'with custom parameters' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'redis':
            package_ensure => 'latest',
          }
          PUPPET
        end

        let(:params) do
          {
            sentinel_monitors: {
              'mymaster' => {
                'redis_host'             => '127.0.0.1',
                'redis_port'             => 6379,
                'quorum'                 => 2,
                'parallel_sync'          => 1,
                'auth_pass'              => 'password',
                'down_after'             => 6000,
                'failover_timeout'       => 28_000,
                'notification_script'    => '/path/to/bar.sh',
                'client_reconfig_script' => '/path/to/foo.sh',
              },
            },
            sentinel_bind: '192.0.2.10',
            protected_mode: false,
            working_dir: '/tmp/redis',
            log_file: '/tmp/barn-sentinel.log'
          }
        end

        let(:expected_content) do
          <<CONFIG
bind 192.0.2.10
port 26379
dir /tmp/redis
daemonize #{facts[:osfamily] == 'RedHat' ? 'no' : 'yes'}
pidfile #{pidfile}
#{protected_mode ? "protected-mode no\n" : ''}
sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 6000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 28000
sentinel auth-pass mymaster password
sentinel notification-script mymaster /path/to/bar.sh
sentinel client-reconfig-script mymaster /path/to/foo.sh

loglevel notice
logfile /tmp/barn-sentinel.log
CONFIG
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('redis::sentinel') }
        it { is_expected.to contain_file(config_file_orig).with_content(expected_content) }

        it { is_expected.to contain_package(sentinel_package_name).with_ensure('latest') }
      end

      describe 'with array sentinel bind' do
        let(:params) do
          {
            sentinel_monitors: {
              'cow' => {
                'redis_host'             => '127.0.0.1',
                'redis_port'             => 6379,
                'quorum'                 => 2,
                'parallel_sync'          => 1,
                'auth_pass'              => 'password',
                'down_after'             => 6000,
                'failover_timeout'       => 28_000,
                'notification_script'    => '/path/to/bar.sh',
                'client_reconfig_script' => '/path/to/foo.sh',
              },
            },
            sentinel_bind: ['192.0.2.10', '192.168.1.1'],
            working_dir: '/tmp/redis',
            log_file: '/tmp/barn-sentinel.log'
          }
        end

        let(:expected_content) do
          <<CONFIG
bind 192.0.2.10 192.168.1.1
port 26379
dir /tmp/redis
daemonize #{facts[:osfamily] == 'RedHat' ? 'no' : 'yes'}
pidfile #{pidfile}
protected-mode yes

sentinel monitor cow 127.0.0.1 6379 2
sentinel down-after-milliseconds cow 6000
sentinel parallel-syncs cow 1
sentinel failover-timeout cow 28000
sentinel auth-pass cow password
sentinel notification-script cow /path/to/bar.sh
sentinel client-reconfig-script cow /path/to/foo.sh

loglevel notice
logfile /tmp/barn-sentinel.log
CONFIG
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('redis::sentinel') }
        it { is_expected.to contain_file(config_file_orig).with_content(expected_content) }
      end

      describe 'with package_ensure different from redis::package_ensure' do
        let(:pre_condition) do
          <<-PUPPET
          class { 'redis':
            package_ensure => 'installed',
          }
          PUPPET
        end

        let(:params) do
          {
            package_ensure: 'latest'
          }
        end

        let(:package_ensure) do
          if facts[:os]['family'] == 'Debian'
            'latest'
          else
            'installed'
          end
        end

        it { is_expected.to contain_package(sentinel_package_name).with_ensure(package_ensure) }
      end
    end
  end
end
