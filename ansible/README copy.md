# demo-ansible

demo-ansible

## 安装 ansible

```bash
dnf install -y ansible
```

## 推荐的项目结构

```
demo-ansible/
├── ansible.cfg
├── group_vars/
│   ├── all.yml
├── inventories/
│   ├── <host>.yml
├── playbooks/
│   ├── init-os.yml
├── roles/
│   ├── setup-redhat-repo/
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   ├── vars/
│   │   │   ├── main.yml
├── README.md
```


## 使用示例

```bash
# 测试运行（只看变化）
ansible-playbook playbooks/init-os.yml --check

# 指定 hosts 运行
ansible-playbook -i inventories/own/hosts playbooks/os/demo.yml

# 正式运行
ansible-playbook playbooks/init-os.yml

# 只运行时区设置
ansible-playbook playbooks/init-os.yml --tags os-init --skip-tags setup-redhat,setup-ubuntu

# 禁用 SELinux 模块（在 group_vars 中覆盖）
# 在 group_vars/all.yml 中设置：
# os_init_disable_selinux: false
```