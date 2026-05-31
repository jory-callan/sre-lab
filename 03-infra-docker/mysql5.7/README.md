# mysqldump 备份语句
mysqldump -h 192.168.11.11  -u root -proot --max-allowed-packet=100M --single-transaction --quick --lock-tables=false --extended-insert=false --no-create-db --no-create-info --skip-triggers --skip-add-drop-table db_test  table_test1  > /tmp/test1.sql



# 导入语句
#!/bin/bash
mysql -h 127.0.0.1  -u root -proot  -e "USE db_test ; source /path/to/your/sql/file.sql"