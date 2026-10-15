
login = "hidriouc"

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "#{login}IOTParent"
  
  config.vm.synced_folder ".", "/workspace"

  config.vm.network "forwarded_port", guest: 8888, host: 8888,
                    host_ip: "127.0.0.1", auto_correct: false
                    
  config.vm.network "forwarded_port", guest: 8080, host: 8080,
                    host_ip: "127.0.0.1", auto_correct: false

  config.vm.provider "virtualbox" do |vb|
    vb.name = "#{login}IOTParent"
    # P1/P2 run as nested VirtualBox guests. Keep the parent allocation fixed.
    vb.cpus = 2
    vb.memory = 3072
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
  end

  config.vm.provision "shell", path: "p3/scripts/install-tools.sh"
end
