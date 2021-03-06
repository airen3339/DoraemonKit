package com.didichuxing.doraemonkit.kit.mc.all.ui

import android.widget.TextView
import com.didichuxing.doraemonkit.mc.R

import com.didichuxing.doraemonkit.widget.brvah.BaseQuickAdapter
import com.didichuxing.doraemonkit.widget.brvah.viewholder.BaseViewHolder


/**
 * didi Create on 2022/1/18 .
 *
 * Copyright (c) 2022/1/18 by didiglobal.com.
 *
 * @author <a href="realonlyone@126.com">zhangjun</a>
 * @version 1.0
 * @Date 2022/1/18 8:12 下午
 * @Description 用一句话说明文件功能
 */

class McClientHistoryAdapter(clientList: MutableList<McClientHistory>, callback: (client:McClientHistory) -> Unit) :
    BaseQuickAdapter<McClientHistory, BaseViewHolder>(R.layout.dk_item_mc_client, clientList) {

    val callback2 = callback
    override fun convert(holder: BaseViewHolder, item: McClientHistory) {
        holder.getView<TextView>(R.id.tv_name).text = "主机名称:${item.name}"
        holder.getView<TextView>(R.id.tv_address).text = "主机地址:ws://${item.host}:${item.port}/${item.path}"
        holder.getView<TextView>(R.id.tv_time).text = "采集时间:${item.time}"
        holder.getView<TextView>(R.id.connect).setOnClickListener {
            callback2(item)
        }
    }
}

data class McClientHistory(
    val host: String,
    val port: Int,
    val path: String,
    val name: String,
    val time: String
)
