### 核心概念

- **Inventory（库存）**：定义Ansible管理的主机列表。
- **Playbook（剧本）**：定义任务的有序列表，用于配置和管理主机。
- **Role（角色）**：将任务和变量组织成可重复使用的模块，用于定义主机的特定配置。
- **Module（模块）**：Ansible的基本执行单元，用于执行任务（如文件操作、服务管理等）。
- **Task（任务）**：Playbook中的一个具体操作，由一个或多个模块组成。

如果需要最简单的 可以只写一个 playbook  ， 里面直接写 task 就行了

如果需要复用，可以用 role 复用，role 里面默认执行的是 task/main.yml 文件

一般采用 `ansible-galaxy init roles/role_name` 来初始化 role

role 并不是最小的执行单元。最小的执行单元是 task ，role 可以包含多个 task 文件

其中tasks可以选择按照： main.yml    pre.yml   process.yml   post.yml   的流程进行处理。
例如安装docker软件，需要先检查是否安装，安装了直接结束。如果没有安装，就需要安装docker。

### playbook 详解

playbook 是 ansible 最常用的执行单元，它定义了一个任务列表，每个任务都是一个模块的调用。

playbook 可以包含多个任务，每个任务都有自己的模块和参数。

playbook 可以根据需要定义多个主机组，每个主机组都有自己的任务列表。

playbook 可以根据需要定义多个标签，每个标签都可以用来过滤任务列表。

### ansible 常用命令

```bash
# 测试连接
ansible -i inventory/hosts rocky9_servers -m ping

# 检查剧本语法
ansible-playbook -i inventory/test/hosts playbooks/setup-docker.yml --syntax-check

# 模拟运行（查看会做什么）
ansible-playbook -i inventory/test/hosts playbooks/setup-docker.yml --check

# 实际运行
ansible-playbook -i inventory/test/hosts playbooks/setup-docker.yml

# 只安装部分（使用标签）
ansible-playbook -i inventory/test/hosts playbooks/setup-docker.yml --tags "install,configure"

# 跳过安装，只配置
ansible-playbook -i inventory/test/hosts playbooks/setup-docker.yml --skip-tags "install"
```

### 其他命令
```bash
# 参数讲解
# -i 指定主机文件
# -m ansible的模块，例如：  -m ping
# -a 紧跟着 -m 代表传递的参数，例如： -m copy -a "src=/local/file dest=/remote/file"
# -e 优先级最高的变量。例如：-e "app_version=2.0"

# 基础命令
# 1. 测试连接（使用密码）
ansible all -i hosts -m ping -k
# 2. 执行剧本
ansible-playbook -i hosts playbook.yml
# 3. 查看清单中的主机
ansible -i hosts --list-hosts all
# 4. 对特定主机组执行命令
ansible web -i hosts -m shell -a "uptime"

# 带认证的命令
# 使用SSH密钥
ansible all -i hosts -m ping --private-key ~/.ssh/id_rsa
# 使用sudo（会提示密码）
ansible-playbook -i hosts playbook.yml -K
# 指定用户
ansible all -i hosts -u ubuntu -m ping
```

