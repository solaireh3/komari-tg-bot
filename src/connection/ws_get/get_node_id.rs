use crate::connection::msg_fixer;
use crate::connection::ws_get::status::sort_ws_data;
use crate::connection::ws_get::{ApiWsDataHashMapValue, get_ws};
use crate::{ErrorString, connection};
use teloxide::prelude::Message;
use tokio::task::JoinHandle;

pub async fn ws_get_node_id(msg: Message) -> Result<String, ErrorString> {
    let telegram_id = if let Some(user) = msg.clone().from {
        user.id.0 as i64
    } else {
        return Err(String::from("无法获取用户ID"));
    };

    let ws_handle = tokio::spawn(async move { Ok(sort_ws_data(get_ws(telegram_id).await?)) });
    let http_handle: JoinHandle<Result<connection::api_nodes::ApiNodes, ErrorString>> =
        tokio::spawn(async move {
            let nodes = connection::api_nodes::get_api_nodes(telegram_id).await?;
            Ok(nodes)
        });

    let (sorted_ws_data, nodes): (
        Result<Vec<(String, ApiWsDataHashMapValue)>, ErrorString>,
        Result<connection::api_nodes::ApiNodes, ErrorString>,
    ) = tokio::try_join!(ws_handle, http_handle)
        .map_err(|e| format!("无法运行 Tokio 线程: {e}"))?;

    let sorted_ws_data = sorted_ws_data?;
    let nodes = nodes?;

    let mut message_str = String::new();

    let mut counter = 0;

    for (node_uuid, _) in sorted_ws_data {
        counter += 1;

        let node = nodes
            .data
            .iter()
            .find(|node| node.uuid == node_uuid)
            .ok_or("找不到该序号的服务器")?;

        message_str.push_str(&format!("`{}` - {}\n", counter, node.name));
    }

    Ok(msg_fixer(message_str))
}
