/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _LINUX_RK_CAMERA_MODULE_COMPAT_H
#define _LINUX_RK_CAMERA_MODULE_COMPAT_H

#include <linux/ioctl.h>
#include <linux/types.h>
#include <linux/videodev2.h>

#define RKMODULE_NAME_LEN 32

#define RKMODULE_CAMERA_MODULE_INDEX "rockchip,camera-module-index"
#define RKMODULE_CAMERA_MODULE_FACING "rockchip,camera-module-facing"
#define RKMODULE_CAMERA_MODULE_NAME "rockchip,camera-module-name"
#define RKMODULE_CAMERA_LENS_NAME "rockchip,camera-module-lens-name"

struct rkmodule_base_inf {
	char sensor[RKMODULE_NAME_LEN];
	char module[RKMODULE_NAME_LEN];
	char lens[RKMODULE_NAME_LEN];
};

struct rkmodule_inf {
	struct rkmodule_base_inf base;
};

struct rkmodule_awb_cfg {
	__u32 enable;
	__u32 golden_r_value;
	__u32 golden_b_value;
	__u32 golden_gr_value;
	__u32 golden_gb_value;
};

#define RKMODULE_GET_MODULE_INFO _IOR('V', BASE_VIDIOC_PRIVATE + 0, struct rkmodule_inf)
#define RKMODULE_AWB_CFG _IOW('V', BASE_VIDIOC_PRIVATE + 1, struct rkmodule_awb_cfg)
#define RKMODULE_SET_QUICK_STREAM _IOW('V', BASE_VIDIOC_PRIVATE + 2, __u32)

#endif

