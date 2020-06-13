package com.didichuxing.doraemonkit.kit.performance

import android.content.pm.PackageManager
import android.os.Bundle
import android.view.View
import android.widget.CheckBox
import androidx.annotation.StringRes
import androidx.core.app.ActivityCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.didichuxing.doraemonkit.R
import com.didichuxing.doraemonkit.kit.core.BaseFragment
import com.didichuxing.doraemonkit.kit.core.SettingItem
import com.didichuxing.doraemonkit.kit.core.SettingItemAdapter
import com.didichuxing.doraemonkit.kit.core.SettingItemAdapter.OnSettingItemClickListener
import com.didichuxing.doraemonkit.kit.core.SettingItemAdapter.OnSettingItemSwitchListener
import com.didichuxing.doraemonkit.kit.performance.manager.PerformanceDokitViewManager
import com.didichuxing.doraemonkit.kit.performance.manager.PerformanceFragmentCloseListener
import com.didichuxing.doraemonkit.widget.titlebar.HomeTitleBar
import java.util.*

/**
 *
 * Desc:性能监控基础fragment
 * <p>
 * Date: 2020-06-09
 * Company:
 * Updater:
 * Update Time:
 * Update Comments:
 *
 * Author: pengyushan
 */
abstract class AbsPerformanceFragment : BaseFragment(), PerformanceFragmentCloseListener {
    private var mSettingItemAdapter: SettingItemAdapter? = null
    private var mSettingList: RecyclerView? = null
    override fun onRequestLayout(): Int {
        return R.layout.dk_fragment_performance
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        initView()
    }

    protected abstract val title: Int
    protected abstract val performanceType: Int
    protected abstract fun getSettingItems(list: MutableList<SettingItem>):MutableList<SettingItem>?
    protected abstract val itemSwitchListener: OnSettingItemSwitchListener?
    protected abstract val itemClickListener: OnSettingItemClickListener?
    protected fun openChartPage(@StringRes title: Int, type: Int) {
        PerformanceDokitViewManager.open(type, getString(title), this)
    }

    protected fun closeChartPage() {
        PerformanceDokitViewManager.close(performanceType, getString(title))
    }

    private fun initView() {
        val titleBar = findViewById<HomeTitleBar>(R.id.title_bar)
        titleBar.setTitle(title)
        titleBar.setListener(object : HomeTitleBar.OnTitleBarClickListener {
            override fun onRightClick() {
                activity!!.finish()
            }
        })
        mSettingList = findViewById(R.id.setting_list)
        mSettingList!!.layoutManager = LinearLayoutManager(context)
        mSettingItemAdapter = SettingItemAdapter(context)
        mSettingItemAdapter!!.append(getSettingItems(ArrayList()))
        mSettingItemAdapter!!.setOnSettingItemSwitchListener(object : OnSettingItemSwitchListener {
            override fun onSettingItemSwitch(view: View, data: SettingItem, on: Boolean) {
                if (on && !ownPermissionCheck()) {
                    if (view is CheckBox) {
                        view.isChecked = false
                    }
                    requestPermissions(PERMISSIONS_STORAGE, REQUEST_EXTERNAL_STORAGE)
                    return
                }
                val itemSwitchListener = itemSwitchListener
                itemSwitchListener?.onSettingItemSwitch(view, data, on)
            }
        })
        mSettingItemAdapter!!.setOnSettingItemClickListener(object : OnSettingItemClickListener {
            override fun onSettingItemClick(view: View, data: SettingItem) {
                if (!ownPermissionCheck()) {
                    requestPermissions(PERMISSIONS_STORAGE, REQUEST_EXTERNAL_STORAGE)
                    return
                }
                val itemClickListener = itemClickListener
                itemClickListener?.onSettingItemClick(view, data)
            }
        })
        mSettingList!!.adapter = mSettingItemAdapter
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        if (requestCode == REQUEST_EXTERNAL_STORAGE) {
            for (grantResult in grantResults) {
                if (grantResult == -1) {
                    showToast(R.string.dk_error_tips_permissions_less)
                }
            }
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun ownPermissionCheck(): Boolean {
        val permission = ActivityCompat.checkSelfPermission(activity!!, "android.permission.WRITE_EXTERNAL_STORAGE")
        return permission == PackageManager.PERMISSION_GRANTED
    }

    override fun onClose(performanceTypee: Int) {
        if (performanceTypee != performanceTypee) {
            return
        }
        if (mSettingList == null || mSettingList!!.isComputingLayout) {
            return
        }
        if (mSettingItemAdapter == null) {
            return
        }
        if (!mSettingItemAdapter!!.data[0].isChecked) {
            return
        }
        mSettingItemAdapter!!.data[0].isChecked = false
        mSettingItemAdapter!!.notifyItemChanged(0)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        mSettingItemAdapter = null
    }

    override fun onDestroy() {
        super.onDestroy()
        //移除监听
        PerformanceDokitViewManager.onPerformanceSettingFragmentDestroy(this)
    }

    companion object {
        private val PERMISSIONS_STORAGE = arrayOf(
                "android.permission.READ_EXTERNAL_STORAGE",
                "android.permission.WRITE_EXTERNAL_STORAGE")
        private const val REQUEST_EXTERNAL_STORAGE = 2
    }
}