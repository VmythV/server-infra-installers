# 日志规范

每个软件必须记录：

- 主日志：`/var/log/<software>-installer.log`
- 步骤日志：`/var/log/<software>-installer-steps.jsonl`
- 状态文件：`/var/lib/<software>-installer/state.env`
- 步骤状态：`/var/lib/<software>-installer/steps/*.status`

失败必须记录：

- 失败步骤
- 失败命令
- 退出码
- 开始时间和结束时间
- 日志路径
- 关键 stdout/stderr 摘要
