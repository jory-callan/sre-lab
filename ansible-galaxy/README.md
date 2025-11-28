# ansible-galaxy

用 roles 目录来定义可复用的“功能模块”（如安装软件、配置服务）。
每个 role 都是一个独立的目录，包含了该功能模块的所有文件（如 tasks、handlers、vars、files、templates 等）。

用 playbooks 目录来定义具体的“工作流程”，通过组合不同的 roles 来完成一个完整的运维任务。
每个 playbook 都是一个独立的文件，包含了该运维任务的所有步骤（如 hosts、tasks、roles 等）。

## init 

```bash
dnf install -y ansible

# init collection
ansible-galaxy collection init sre.server
# init role
cd sre/server/roles
ansible-galaxy init roles/role-name
```

## run playbook

格式：ansible-playbook <namespace>.<collection_name>.<playbook_name>

```bash
# run playbook in collection
ansible-playbook sre.server.playbook-name

# run playbook in role
ansible-playbook -i inventory.ini myops.servers.deploy_nginx.yml

# 测试运行（只看变化）
ansible-playbook playbooks/init-os.yml --check

# 指定 hosts 运行
ansible-playbook -i inventories/own/hosts playbooks/os/demo.yml

# 正式运行
ansible-playbook playbooks/init-os.yml

# 只运行时区设置
ansible-playbook playbooks/init-os.yml --tags os-init --skip-tags setup-redhat,setup-ubuntu

```