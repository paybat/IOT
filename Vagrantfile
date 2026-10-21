
login = "hidriouc"
vm_cpus = Integer(ENV.fetch("IOT_VM_CPUS", "2"))
vm_memory = Integer(ENV.fetch("IOT_VM_MEMORY_MB", "3072"))

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "#{login}IOTParent"
  
  config.vm.synced_folder ".", "/workspace"

  config.vm.network "forwarded_port", guest: 8888, host: 8888,
                    host_ip: "127.0.0.1", auto_correct: false
                    
  config.vm.network "forwarded_port", guest: 8080, host: 8080,
                    host_ip: "127.0.0.1", auto_correct: false

  config.vm.network "forwarded_port", guest: 8081, host: 8081,
                    host_ip: "127.0.0.1", auto_correct: false

  config.vm.provider "virtualbox" do |vb|
    vb.name = "#{login}IOTParent"
    # P1/P2 run as nested VirtualBox guests. Keep the parent allocation fixed.
    vb.cpus = vm_cpus
    vb.memory = vm_memory
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
  end

  if ENV["IOT_BONUS"] == "1"
    config.vm.provision "shell", path: "bonus/scripts/install-tools.sh"
  else
    config.vm.provision "shell", path: "p3/scripts/install-tools.sh"
  end
end
