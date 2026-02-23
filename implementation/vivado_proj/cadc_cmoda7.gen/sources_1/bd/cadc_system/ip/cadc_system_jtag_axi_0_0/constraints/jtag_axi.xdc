# (c) Copyright 2023 Advanced Micro Devices, Inc. All rights reserved.
#
# This file contains confidential and proprietary information
# of AMD and is protected under U.S. and international copyright
# and other intellectual property laws.
#
# DISCLAIMER
# This disclaimer is not a license and does not grant any
# rights to the materials distributed herewith. Except as
# otherwise provided in a valid license issued to you by
# AMD, and to the maximum extent permitted by applicable
# law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
# WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
# AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
# BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
# INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
# (2) AMD shall not be liable (whether in contract or tort,
# including negligence, or under any other theory of
# liability) for any loss or damage of any kind or nature
# related to, arising under or in connection with these
# materials, including for any direct, or any indirect,
# special, incidental, or consequential loss or damage
# (including loss of data, profits, goodwill, or any type of
# loss or damage suffered as a result of any action brought
# by a third party) even if such damage or loss was
# reasonably foreseeable or AMD had been advised of the
# possibility of the same.
#
# CRITICAL APPLICATIONS
# AMD products are not designed or intended to be fail-
# safe, or for use in any application requiring fail-safe
# performance, such as life-support or safety devices or
# systems, Class III medical devices, nuclear facilities,
# applications related to the deployment of airbags, or any
# other applications that could lead to death, personal
# injury, or severe property or environmental damage
# (individually and collectively, "Critical
# Applications"). Customer assumes the sole risk and
# liability of any use of AMD products in Critical
# Applications, subject only to applicable laws and
# regulations governing limitations on product liability.
#
# THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
# PART OF THIS FILE AT ALL TIMES.
############################################################
set src_sts [get_cells -hierarchical -filter { NAME =~ "*status_reg_datain_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set dest_sts [get_cells -hierarchical -filter { NAME =~ "*status_reg_datain_ff_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set_false_path -from $src_sts -to $dest_sts; 

#set_max_delay -from $src_sts -to $dest_sts -datapath_only 40.0

set src_wren [get_cells -hierarchical -filter { NAME =~ "*wr_axi_en_exec_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set dest_wren [get_cells -hierarchical -filter { NAME =~ "*wr_axi_en_exec_ff_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }] 
set_false_path -from $src_wren -to $dest_wren;

set src_rden [get_cells -hierarchical -filter { NAME =~ "*rd_axi_en_exec_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set dest_rden [get_cells -hierarchical -filter { NAME =~ "*rd_axi_en_exec_ff_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set_false_path -from $src_rden -to $dest_rden;

set src_softrst [get_cells -hierarchical -filter { NAME =~ "*fifo_rst_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set dest_softrst [get_cells -hierarchical -filter { NAME =~ "*fifo_rst_ff1_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set_false_path -from $src_softrst -to $dest_softrst;

set src_arstn [get_cells -hierarchical -filter { NAME =~ "*axi_aresetn_ff_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set dest_arstn [get_cells -hierarchical -filter { NAME =~ "*aresetn_xsdb_ff_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set_false_path -from $src_arstn -to $dest_arstn;

set src_wrd [get_cells -hierarchical -filter { NAME =~ "*wr_cmd_fifowren_xsdb_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set dest_wrd [get_cells -hierarchical -filter { NAME =~ "*wr_cmd_fifowren_axi_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set_false_path -from $src_wrd -to $dest_wrd;

set src_rdd [get_cells -hierarchical -filter { NAME =~ "*rd_cmd_fifowren_xsdb_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set dest_rdd [get_cells -hierarchical -filter { NAME =~ "*rd_cmd_fifowren_axi_reg*" && ( PRIMITIVE_TYPE =~ FLOP_LATCH.flop.*   || PRIMITIVE_TYPE == RTL_REGISTER.flop.RTL_REG || PRIMITIVE_TYPE =~ REGISTER.SDR.*  ) }]
set_false_path -from $src_rdd -to $dest_rdd;
