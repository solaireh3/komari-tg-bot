use crate::ErrorString;
use crate::connection::msg_fixer;
use crate::connection::ws_get::get_ws;
use crate::db::{DB_POOL, query_monitor_by_telegram_id};

pub async fn parse_ws_total_status(telegram_id: i64) -> Result<String, ErrorString> {
    let ws_data = match get_ws(telegram_id).await {
        Ok(ws_data) => ws_data,
        Err(e) => {
            return Err(format!("无法连接到 Komari Websocket 服务器: {e}"));
        }
    };

    let monitor = query_monitor_by_telegram_id(
        DB_POOL
            .get()
            .unwrap_or_else(|| panic!("数据库连接池未初始化")),
        telegram_id,
    )
    .await?
    .ok_or(String::from(
        "服务器未连接，请先使用 /connect [http url] 连接",
    ))?;

    let online_nodes_count = ws_data.data.online.len();
    let total_nodes_count = monitor.total_server_count;
    let percent_online = online_nodes_count as f64 / f64::from(total_nodes_count) * 100.0;

    let avg_cpu_usage = ws_data
        .data
        .data
        .values()
        .map(|node| node.cpu.usage)
        .sum::<f64>()
        / ws_data.data.data.len() as f64;

    let total_total_ram = ws_data
        .data
        .data
        .values()
        .map(|node| node.ram.total)
        .sum::<u64>() as f64
        / 1024.0
        / 1024.0
        / 1024.0;
    let total_used_ram = ws_data
        .data
        .data
        .values()
        .map(|node| node.ram.used)
        .sum::<u64>() as f64
        / 1024.0
        / 1024.0
        / 1024.0;
    let avg_ram_usage = total_used_ram / total_total_ram * 100.0;

    let total_total_swap = ws_data
        .data
        .data
        .values()
        .map(|node| node.swap.total)
        .sum::<u64>() as f64
        / 1024.0
        / 1024.0
        / 1024.0;
    let total_used_swap = ws_data
        .data
        .data
        .values()
        .map(|node| node.swap.used)
        .sum::<u64>() as f64
        / 1024.0
        / 1024.0
        / 1024.0;
    let avg_swap_usage = total_used_swap / total_total_swap * 100.0;

    let total_total_disk = ws_data
        .data
        .data
        .values()
        .map(|node| node.disk.total)
        .sum::<u64>() as f64
        / 1024.0
        / 1024.0
        / 1024.0;
    let total_used_disk = ws_data
        .data
        .data
        .values()
        .map(|node| node.disk.used)
        .sum::<u64>() as f64
        / 1024.0
        / 1024.0
        / 1024.0;
    let avg_disk_usage = total_used_disk / total_total_disk * 100.0;

    let avg_load1 = ws_data
        .data
        .data
        .values()
        .map(|node| node.load.load1)
        .sum::<f64>()
        / ws_data.data.data.len() as f64;
    let avg_load5 = ws_data
        .data
        .data
        .values()
        .map(|node| node.load.load5)
        .sum::<f64>()
        / ws_data.data.data.len() as f64;
    let avg_load15 = ws_data
        .data
        .data
        .values()
        .map(|node| node.load.load15)
        .sum::<f64>()
        / ws_data.data.data.len() as f64;

    let total_total_net_down = ws_data
        .data
        .data
        .values()
        .map(|node| node.network.total_down)
        .sum::<u64>() as f64
        / 1024.0
        / 1024.0
        / 1024.0;
    let total_total_net_up = ws_data
        .data
        .data
        .values()
        .map(|node| node.network.total_up)
        .sum::<u64>() as f64
        / 1024.0
        / 1024.0
        / 1024.0;
    let total_net_down = ws_data
        .data
        .data
        .values()
        .map(|node| node.network.down)
        .sum::<u64>() as f64
        / 125000.0;
    let total_net_up = ws_data
        .data
        .data
        .values()
        .map(|node| node.network.up)
        .sum::<u64>() as f64
        / 125000.0;

    let total_tcp_connections = ws_data
        .data
        .data
        .values()
        .map(|node| node.connections.tcp)
        .sum::<u32>();
    let total_udp_connections = ws_data
        .data
        .data
        .values()
        .map(|node| node.connections.udp)
        .sum::<u32>();

    let title = monitor.site_name;

    Ok(msg_fixer(format!(
        r"{title} 总览
Online: `{online_nodes_count}` / `{total_nodes_count}` `{percent_online:.2}%`
Avg Cpu: `{avg_cpu_usage:.2}%`
Avg Load 1: `{avg_load1:.2}`
Avg Load 5: `{avg_load5:.2}`
Avg Load 15: `{avg_load15:.2}`

Mem: `{total_used_ram:.2} GB` / `{total_total_ram:.2} GB` `{avg_ram_usage:.2}%`
Swap: `{total_used_swap:.2} GB` / `{total_total_swap:.2} GB` `{avg_swap_usage:.2}%`
Disk: `{total_used_disk:.2} GB` / `{total_total_disk:.2} GB` `{avg_disk_usage:.2}%`

Total Download: `{total_total_net_down:.2} GB`
Total Upload: `{total_total_net_up:.2} GB`
Download Speed: `{total_net_down:.2} Mbps`
Upload Speed: `{total_net_up:.2} Mbps`
Connections: `{total_tcp_connections} TCP` / `{total_udp_connections} UDP`"
    )))
}
