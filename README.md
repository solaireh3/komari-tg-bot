# komari-tg-bot



**一键命令**



```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xymn2023/komari-tg-bot/main/deploy.sh)"
```



**说明**：已同步[原仓库](https://github.com/GenshinMinecraft/komari-tg-bot)并实现所有功能，支持群组使用。







**bot菜单快捷设置**

```
start - 欢迎使用
connect - 连接到 Komari 服务
disconnect - 断开已保存的连接
update - 更新已保存连接
get_node_id - 获取所有服务器ID
total_status - 获取所有服务器运行状态
status - 获取指定服务器
generate_notification_token - 生成令牌
```



## Config Demo

`config.json`
```json
{
  "db_file": "bot.db",
  "telegram_token": "123456:123456",
  "bot_name": "komaritgbot",
  "callback_http_port": 80,
  "callback_http_url": "https://komari-bot.c1oudf1are.eu.org",
  "log_level": "info"
}
```

## LICENSE

本项目根据 WTFPL 许可证开源

```
        DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
                    Version 2, December 2004 

 Copyright (C) 2004 Sam Hocevar <sam@hocevar.net> 

 Everyone is permitted to copy and distribute verbatim or modified 
 copies of this license document, and changing it is allowed as long 
 as the name is changed. 

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE 
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION 

  0. You just DO WHAT THE FUCK YOU WANT TO.

```

