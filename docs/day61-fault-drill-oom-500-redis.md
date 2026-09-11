# Day 61 · 故障演练 OOM / 5xx / Redis

清单：`dev/platform/observability/faultlab/day61-workloads.yaml`  
脚本：`scripts/day61-fault-drills.sh`

```bash
bash scripts/day61-fault-drills.sh status
bash scripts/day61-fault-drills.sh oom
bash scripts/day61-fault-drills.sh http500
bash scripts/day61-fault-drills.sh redis-down
bash scripts/day61-fault-drills.sh redis-up
bash scripts/day61-fault-drills.sh cleanup
```

注意：`library/redis` / `busybox` 需已在 Harbor；缺失则先镜像同步。直播演练前确认。
