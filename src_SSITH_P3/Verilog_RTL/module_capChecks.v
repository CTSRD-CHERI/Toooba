//
// Generated by Bluespec Compiler, version 2019.05.beta2 (build a88bf40db, 2019-05-24)
//
// On Mon Jun 29 23:45:24 BST 2020
//
//
// Ports:
// Name                         I/O  size props
// capChecks                      O    12
// capChecks_a                    I   163
// capChecks_b                    I   163
// capChecks_ddc                  I   163
// capChecks_toCheck              I    47
// capChecks_cap_exact            I     1
//
// Combinational paths from inputs to outputs:
//   (capChecks_a,
//    capChecks_b,
//    capChecks_ddc,
//    capChecks_toCheck,
//    capChecks_cap_exact) -> capChecks
//
//

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif

module module_capChecks(capChecks_a,
			capChecks_b,
			capChecks_ddc,
			capChecks_toCheck,
			capChecks_cap_exact,
			capChecks);
  // value method capChecks
  input  [162 : 0] capChecks_a;
  input  [162 : 0] capChecks_b;
  input  [162 : 0] capChecks_ddc;
  input  [46 : 0] capChecks_toCheck;
  input  capChecks_cap_exact;
  output [11 : 0] capChecks;

  // signals for module outputs
  wire [11 : 0] capChecks;

  // remaining internal signals
  wire [10 : 0] IF_capChecks_toCheck_BIT_46_AND_NOT_capChecks__ETC___d347;
  wire [5 : 0] IF_capChecks_toCheck_BIT_34_9_AND_NOT_capCheck_ETC___d263,
	       IF_capChecks_toCheck_BIT_41_3_AND_capChecks_dd_ETC___d270,
	       IF_capChecks_toCheck_BIT_42_4_AND_capChecks_b__ETC___d266,
	       IF_capChecks_toCheck_BIT_43_7_AND_capChecks_a__ETC___d267,
	       IF_capChecks_toCheck_BIT_45_AND_NOT_capChecks__ETC___d272;
  wire [4 : 0] IF_NOT_capChecks_toCheck_BIT_34_9_98_OR_capChe_ETC___d336,
	       IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d339,
	       IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d340,
	       IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d342,
	       IF_NOT_capChecks_toCheck_BIT_46_56_OR_capCheck_ETC___d346,
	       IF_capChecks_toCheck_BIT_36_1_AND_NOT_capCheck_ETC___d337,
	       IF_capChecks_toCheck_BIT_41_3_AND_capChecks_dd_ETC___d344;
  wire NOT_capChecks_a_BITS_43_TO_38_06_ULE_52_07_08__ETC___d124,
       NOT_capChecks_toCheck_BIT_28_2_90_OR_0_CONCAT__ETC___d289,
       NOT_capChecks_toCheck_BIT_30_4_07_OR_capChecks_ETC___d316,
       NOT_capChecks_toCheck_BIT_30_4_07_OR_capChecks_ETC___d329,
       NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d287,
       NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d304,
       NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d311,
       NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d319,
       NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d332,
       NOT_capChecks_toCheck_BIT_36_1_94_OR_capChecks_ETC___d325,
       NOT_capChecks_toCheck_BIT_39_5_68_OR_NOT_capCh_ETC___d276,
       NOT_capChecks_toCheck_BIT_41_3_62_OR_NOT_capCh_ETC___d278,
       NOT_capChecks_toCheck_BIT_43_7_75_OR_NOT_capCh_ETC___d274,
       NOT_capChecks_toCheck_BIT_45_58_OR_capChecks_a_ETC___d292,
       _0_CONCAT_capChecks_a_BITS_62_TO_45_1_3_ULE_262139___d54,
       _0_CONCAT_capChecks_a_BITS_81_TO_78_4_AND_capCh_ETC___d102,
       capChecks_a_BITS_43_TO_38_06_ULE_52_07_AND_NOT_ETC___d223,
       capChecks_a_BITS_43_TO_38_06_ULE_52___d107,
       capChecks_a_BITS_62_TO_45_1_EQ_capChecks_b_BIT_ETC___d58,
       capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86,
       capChecks_b_BITS_159_TO_96_5_ULE_262139___d90,
       capChecks_toCheck_BIT_28_2_AND_NOT_0_CONCAT_ca_ETC___d146,
       capChecks_toCheck_BIT_28_2_AND_NOT_0_CONCAT_ca_ETC___d306,
       capChecks_toCheck_BIT_29_9_AND_NOT_capChecks_b_ETC___d137,
       capChecks_toCheck_BIT_29_9_AND_NOT_capChecks_b_ETC___d283,
       capChecks_toCheck_BIT_33_3_AND_capChecks_b_BIT_ETC___d259,
       capChecks_toCheck_BIT_34_9_AND_NOT_capChecks_a_ETC___d142,
       capChecks_toCheck_BIT_39_5_AND_capChecks_a_BIT_ETC___d150,
       capChecks_toCheck_BIT_39_5_AND_capChecks_a_BIT_ETC___d298,
       capChecks_toCheck_BIT_41_3_AND_capChecks_ddc_B_ETC___d152,
       capChecks_toCheck_BIT_41_3_AND_capChecks_ddc_B_ETC___d300,
       capChecks_toCheck_BIT_43_7_AND_capChecks_a_BIT_ETC___d148,
       capChecks_toCheck_BIT_43_7_AND_capChecks_a_BIT_ETC___d296;

  // value method capChecks
  assign capChecks =
	     { capChecks_toCheck[46] && !capChecks_ddc[162] ||
	       capChecks_toCheck[45] && !capChecks_a[162] ||
	       capChecks_toCheck[44] && !capChecks_b[162] ||
	       capChecks_toCheck_BIT_41_3_AND_capChecks_ddc_B_ETC___d152,
	       IF_capChecks_toCheck_BIT_46_AND_NOT_capChecks__ETC___d347 } ;

  // remaining internal signals
  assign IF_NOT_capChecks_toCheck_BIT_34_9_98_OR_capChe_ETC___d336 =
	     ((!capChecks_toCheck[34] || capChecks_a[67]) &&
	      (!capChecks_toCheck[33] || !capChecks_b[67]) &&
	      capChecks_toCheck[32] &&
	      !capChecks_b[75]) ?
	       5'd26 :
	       5'd27 ;
  assign IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d339 =
	     NOT_capChecks_toCheck_BIT_36_1_94_OR_capChecks_ETC___d325 ?
	       5'd23 :
	       (((!capChecks_toCheck[36] || capChecks_a[74]) &&
		 (!capChecks_toCheck[35] || capChecks_b[74]) &&
		 NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d332) ?
		  5'd24 :
		  IF_capChecks_toCheck_BIT_36_1_AND_NOT_capCheck_ETC___d337) ;
  assign IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d340 =
	     ((!capChecks_toCheck[36] || capChecks_a[74]) &&
	      (!capChecks_toCheck[35] || capChecks_b[74]) &&
	      (capChecks_toCheck[34] && !capChecks_a[67] ||
	       capChecks_toCheck[33] && capChecks_b[67])) ?
	       5'd17 :
	       IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d339 ;
  assign IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d342 =
	     ((!capChecks_toCheck[36] || capChecks_a[74]) &&
	      (!capChecks_toCheck[35] || capChecks_b[74]) &&
	      NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d311) ?
	       5'd8 :
	       (((!capChecks_toCheck[36] || capChecks_a[74]) &&
		 (!capChecks_toCheck[35] || capChecks_b[74]) &&
		 NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d319) ?
		  5'd10 :
		  IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d340) ;
  assign IF_NOT_capChecks_toCheck_BIT_46_56_OR_capCheck_ETC___d346 =
	     ((!capChecks_toCheck[46] || capChecks_ddc[162]) &&
	      NOT_capChecks_toCheck_BIT_45_58_OR_capChecks_a_ETC___d292) ?
	       5'd1 :
	       ((capChecks_toCheck[46] && !capChecks_ddc[162] ||
		 capChecks_toCheck[45] && !capChecks_a[162] ||
		 capChecks_toCheck[44] && !capChecks_b[162]) ?
		  5'd2 :
		  IF_capChecks_toCheck_BIT_41_3_AND_capChecks_dd_ETC___d344) ;
  assign IF_capChecks_toCheck_BIT_34_9_AND_NOT_capCheck_ETC___d263 =
	     (capChecks_toCheck[34] && !capChecks_a[67]) ?
	       capChecks_toCheck[11:6] :
	       (capChecks_toCheck_BIT_33_3_AND_capChecks_b_BIT_ETC___d259 ?
		  capChecks_toCheck[5:0] :
		  ((capChecks_toCheck[26] &&
		    NOT_capChecks_a_BITS_43_TO_38_06_ULE_52_07_08__ETC___d124) ?
		     capChecks_toCheck[11:6] :
		     ((capChecks_toCheck[25] &&
		       capChecks_toCheck[11:6] != 6'd0) ?
			6'd32 :
			capChecks_toCheck[11:6]))) ;
  assign IF_capChecks_toCheck_BIT_36_1_AND_NOT_capCheck_ETC___d337 =
	     (capChecks_toCheck[36] && !capChecks_a[74] ||
	      capChecks_toCheck[35] && !capChecks_b[74]) ?
	       5'd25 :
	       IF_NOT_capChecks_toCheck_BIT_34_9_98_OR_capChe_ETC___d336 ;
  assign IF_capChecks_toCheck_BIT_41_3_AND_capChecks_dd_ETC___d270 =
	     (capChecks_toCheck[41] && capChecks_ddc[162] &&
	      capChecks_ddc[62:45] != 18'd262143) ?
	       6'b100001 :
	       ((capChecks_toCheck[40] && capChecks_a[162] &&
		 capChecks_a[62:45] != 18'd262143 ||
		 capChecks_toCheck[39] && capChecks_a[162] &&
		 capChecks_a[62:45] != 18'd262143 &&
		 capChecks_a[62:45] != 18'd262142) ?
		  capChecks_toCheck[11:6] :
		  ((capChecks_toCheck[38] && capChecks_b[162] &&
		    capChecks_b[62:45] != 18'd262143) ?
		     capChecks_toCheck[5:0] :
		     IF_capChecks_toCheck_BIT_43_7_AND_capChecks_a__ETC___d267)) ;
  assign IF_capChecks_toCheck_BIT_41_3_AND_capChecks_dd_ETC___d344 =
	     capChecks_toCheck_BIT_41_3_AND_capChecks_ddc_B_ETC___d300 ?
	       5'd3 :
	       (capChecks_toCheck_BIT_28_2_AND_NOT_0_CONCAT_ca_ETC___d306 ?
		  5'd4 :
		  IF_NOT_capChecks_toCheck_BIT_36_1_94_OR_capChe_ETC___d342) ;
  assign IF_capChecks_toCheck_BIT_42_4_AND_capChecks_b__ETC___d266 =
	     (capChecks_toCheck[42] &&
	      (capChecks_b[62:45] == 18'd262143 ||
	       capChecks_b[62:45] == 18'd262142 ||
	       capChecks_b[62:45] == 18'd262141 ||
	       capChecks_b[62:45] == 18'd262140)) ?
	       capChecks_toCheck[5:0] :
	       ((capChecks_toCheck[28] &&
		 !_0_CONCAT_capChecks_a_BITS_62_TO_45_1_3_ULE_262139___d54 ||
		 capChecks_toCheck[37] &&
		 !capChecks_a_BITS_62_TO_45_1_EQ_capChecks_b_BIT_ETC___d58 ||
		 capChecks_toCheck[36] && !capChecks_a[74]) ?
		  capChecks_toCheck[11:6] :
		  ((capChecks_toCheck[35] && !capChecks_b[74]) ?
		     capChecks_toCheck[5:0] :
		     IF_capChecks_toCheck_BIT_34_9_AND_NOT_capCheck_ETC___d263)) ;
  assign IF_capChecks_toCheck_BIT_43_7_AND_capChecks_a__ETC___d267 =
	     (capChecks_toCheck[43] &&
	      (capChecks_a[62:45] == 18'd262143 ||
	       capChecks_a[62:45] == 18'd262142 ||
	       capChecks_a[62:45] == 18'd262141 ||
	       capChecks_a[62:45] == 18'd262140)) ?
	       capChecks_toCheck[11:6] :
	       IF_capChecks_toCheck_BIT_42_4_AND_capChecks_b__ETC___d266 ;
  assign IF_capChecks_toCheck_BIT_45_AND_NOT_capChecks__ETC___d272 =
	     (capChecks_toCheck[45] && !capChecks_a[162]) ?
	       capChecks_toCheck[11:6] :
	       ((capChecks_toCheck[44] && !capChecks_b[162]) ?
		  capChecks_toCheck[5:0] :
		  IF_capChecks_toCheck_BIT_41_3_AND_capChecks_dd_ETC___d270) ;
  assign IF_capChecks_toCheck_BIT_46_AND_NOT_capChecks__ETC___d347 =
	     { (capChecks_toCheck[46] && !capChecks_ddc[162]) ?
		 6'b100001 :
		 IF_capChecks_toCheck_BIT_45_AND_NOT_capChecks__ETC___d272,
	       IF_NOT_capChecks_toCheck_BIT_46_56_OR_capCheck_ETC___d346 } ;
  assign NOT_capChecks_a_BITS_43_TO_38_06_ULE_52_07_08__ETC___d124 =
	     !capChecks_a_BITS_43_TO_38_06_ULE_52___d107 ||
	     capChecks_a[43:38] == 6'd52 &&
	     (capChecks_a[37] || capChecks_a[23:22] != 2'b0) ||
	     capChecks_a[43:38] == 6'd51 && capChecks_a[23] ||
	     capChecks_a[64:63] != 2'd0 ;
  assign NOT_capChecks_toCheck_BIT_28_2_90_OR_0_CONCAT__ETC___d289 =
	     (!capChecks_toCheck[28] ||
	      _0_CONCAT_capChecks_a_BITS_62_TO_45_1_3_ULE_262139___d54) &&
	     (!capChecks_toCheck[37] ||
	      capChecks_a_BITS_62_TO_45_1_EQ_capChecks_b_BIT_ETC___d58) &&
	     (!capChecks_toCheck[36] || capChecks_a[74]) &&
	     (!capChecks_toCheck[35] || capChecks_b[74]) &&
	     NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d287 ;
  assign NOT_capChecks_toCheck_BIT_30_4_07_OR_capChecks_ETC___d316 =
	     (!capChecks_toCheck[30] ||
	      capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86) &&
	     (!capChecks_toCheck[29] ||
	      capChecks_b_BITS_159_TO_96_5_ULE_262139___d90) &&
	     (!capChecks_toCheck[27] ||
	      _0_CONCAT_capChecks_a_BITS_81_TO_78_4_AND_capCh_ETC___d102) &&
	     (!capChecks_toCheck[26] ||
	      capChecks_a_BITS_43_TO_38_06_ULE_52_07_AND_NOT_ETC___d223) &&
	     (!capChecks_toCheck[25] || capChecks_toCheck[11:6] == 6'd0) ;
  assign NOT_capChecks_toCheck_BIT_30_4_07_OR_capChecks_ETC___d329 =
	     (!capChecks_toCheck[30] ||
	      capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86) &&
	     (!capChecks_toCheck[29] ||
	      capChecks_b_BITS_159_TO_96_5_ULE_262139___d90) &&
	     (!capChecks_toCheck[27] ||
	      _0_CONCAT_capChecks_a_BITS_81_TO_78_4_AND_capCh_ETC___d102) &&
	     (!capChecks_toCheck[26] ||
	      capChecks_a_BITS_43_TO_38_06_ULE_52_07_AND_NOT_ETC___d223) &&
	     capChecks_toCheck[25] &&
	     capChecks_toCheck[11:6] != 6'd0 ;
  assign NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d287 =
	     (!capChecks_toCheck[34] || capChecks_a[67]) &&
	     (!capChecks_toCheck[33] || !capChecks_b[67]) &&
	     (!capChecks_toCheck[32] || capChecks_b[75]) &&
	     (!capChecks_toCheck[31] || capChecks_b[73]) &&
	     (!capChecks_toCheck[30] ||
	      capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86) &&
	     capChecks_toCheck_BIT_29_9_AND_NOT_capChecks_b_ETC___d283 ;
  assign NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d304 =
	     (!capChecks_toCheck[34] || capChecks_a[67]) &&
	     (!capChecks_toCheck[33] || !capChecks_b[67]) &&
	     (!capChecks_toCheck[32] || capChecks_b[75]) &&
	     (!capChecks_toCheck[31] || capChecks_b[73]) &&
	     capChecks_toCheck[30] &&
	     !capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86 ;
  assign NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d311 =
	     (!capChecks_toCheck[34] || capChecks_a[67]) &&
	     (!capChecks_toCheck[33] || !capChecks_b[67]) &&
	     (!capChecks_toCheck[32] || capChecks_b[75]) &&
	     (!capChecks_toCheck[31] || capChecks_b[73]) &&
	     (!capChecks_toCheck[30] ||
	      capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86) &&
	     (!capChecks_toCheck[29] ||
	      capChecks_b_BITS_159_TO_96_5_ULE_262139___d90) &&
	     capChecks_toCheck[27] &&
	     !_0_CONCAT_capChecks_a_BITS_81_TO_78_4_AND_capCh_ETC___d102 ;
  assign NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d319 =
	     (!capChecks_toCheck[34] || capChecks_a[67]) &&
	     (!capChecks_toCheck[33] || !capChecks_b[67]) &&
	     (!capChecks_toCheck[32] || capChecks_b[75]) &&
	     (!capChecks_toCheck[31] || capChecks_b[73]) &&
	     NOT_capChecks_toCheck_BIT_30_4_07_OR_capChecks_ETC___d316 ;
  assign NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d332 =
	     (!capChecks_toCheck[34] || capChecks_a[67]) &&
	     (!capChecks_toCheck[33] || !capChecks_b[67]) &&
	     (!capChecks_toCheck[32] || capChecks_b[75]) &&
	     (!capChecks_toCheck[31] || capChecks_b[73]) &&
	     NOT_capChecks_toCheck_BIT_30_4_07_OR_capChecks_ETC___d329 ;
  assign NOT_capChecks_toCheck_BIT_36_1_94_OR_capChecks_ETC___d325 =
	     (!capChecks_toCheck[36] || capChecks_a[74]) &&
	     (!capChecks_toCheck[35] || capChecks_b[74]) &&
	     (!capChecks_toCheck[34] || capChecks_a[67]) &&
	     (!capChecks_toCheck[33] || !capChecks_b[67]) &&
	     (!capChecks_toCheck[32] || capChecks_b[75]) &&
	     capChecks_toCheck[31] &&
	     !capChecks_b[73] ;
  assign NOT_capChecks_toCheck_BIT_39_5_68_OR_NOT_capCh_ETC___d276 =
	     (!capChecks_toCheck[39] || !capChecks_a[162] ||
	      capChecks_a[62:45] == 18'd262143 ||
	      capChecks_a[62:45] == 18'd262142) &&
	     (!capChecks_toCheck[38] || !capChecks_b[162] ||
	      capChecks_b[62:45] == 18'd262143) &&
	     NOT_capChecks_toCheck_BIT_43_7_75_OR_NOT_capCh_ETC___d274 ;
  assign NOT_capChecks_toCheck_BIT_41_3_62_OR_NOT_capCh_ETC___d278 =
	     (!capChecks_toCheck[41] || !capChecks_ddc[162] ||
	      capChecks_ddc[62:45] == 18'd262143) &&
	     (!capChecks_toCheck[40] || !capChecks_a[162] ||
	      capChecks_a[62:45] == 18'd262143) &&
	     NOT_capChecks_toCheck_BIT_39_5_68_OR_NOT_capCh_ETC___d276 ;
  assign NOT_capChecks_toCheck_BIT_43_7_75_OR_NOT_capCh_ETC___d274 =
	     (!capChecks_toCheck[43] ||
	      capChecks_a[62:45] != 18'd262143 &&
	      capChecks_a[62:45] != 18'd262142 &&
	      capChecks_a[62:45] != 18'd262141 &&
	      capChecks_a[62:45] != 18'd262140) &&
	     (!capChecks_toCheck[42] ||
	      capChecks_b[62:45] != 18'd262143 &&
	      capChecks_b[62:45] != 18'd262142 &&
	      capChecks_b[62:45] != 18'd262141 &&
	      capChecks_b[62:45] != 18'd262140) ;
  assign NOT_capChecks_toCheck_BIT_45_58_OR_capChecks_a_ETC___d292 =
	     (!capChecks_toCheck[45] || capChecks_a[162]) &&
	     (!capChecks_toCheck[44] || capChecks_b[162]) &&
	     NOT_capChecks_toCheck_BIT_41_3_62_OR_NOT_capCh_ETC___d278 &&
	     NOT_capChecks_toCheck_BIT_28_2_90_OR_0_CONCAT__ETC___d289 ;
  assign _0_CONCAT_capChecks_a_BITS_62_TO_45_1_3_ULE_262139___d54 =
	     { 46'd0, capChecks_a[62:45] } <= 64'd262139 ;
  assign _0_CONCAT_capChecks_a_BITS_81_TO_78_4_AND_capCh_ETC___d102 =
	     { 12'd0,
	       capChecks_a[81:78] & capChecks_b[81:78],
	       3'd0,
	       capChecks_a[77:66] & capChecks_b[77:66] } ==
	     { 12'd0, capChecks_a[81:78], 3'h0, capChecks_a[77:66] } ;
  assign capChecks_a_BITS_43_TO_38_06_ULE_52_07_AND_NOT_ETC___d223 =
	     capChecks_a_BITS_43_TO_38_06_ULE_52___d107 &&
	     (capChecks_a[43:38] != 6'd52 ||
	      !capChecks_a[37] && capChecks_a[23:22] == 2'b0) &&
	     (capChecks_a[43:38] != 6'd51 || !capChecks_a[23]) &&
	     capChecks_a[64:63] == 2'd0 ;
  assign capChecks_a_BITS_43_TO_38_06_ULE_52___d107 =
	     capChecks_a[43:38] <= 6'd52 ;
  assign capChecks_a_BITS_62_TO_45_1_EQ_capChecks_b_BIT_ETC___d58 =
	     capChecks_a[62:45] == capChecks_b[62:45] ;
  assign capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86 =
	     capChecks_b[159:96] == { 46'd0, capChecks_a[62:45] } ;
  assign capChecks_b_BITS_159_TO_96_5_ULE_262139___d90 =
	     capChecks_b[159:96] <= 64'd262139 ;
  assign capChecks_toCheck_BIT_28_2_AND_NOT_0_CONCAT_ca_ETC___d146 =
	     capChecks_toCheck[28] &&
	     !_0_CONCAT_capChecks_a_BITS_62_TO_45_1_3_ULE_262139___d54 ||
	     capChecks_toCheck[37] &&
	     !capChecks_a_BITS_62_TO_45_1_EQ_capChecks_b_BIT_ETC___d58 ||
	     capChecks_toCheck[36] && !capChecks_a[74] ||
	     capChecks_toCheck[35] && !capChecks_b[74] ||
	     capChecks_toCheck_BIT_34_9_AND_NOT_capChecks_a_ETC___d142 ;
  assign capChecks_toCheck_BIT_28_2_AND_NOT_0_CONCAT_ca_ETC___d306 =
	     capChecks_toCheck[28] &&
	     !_0_CONCAT_capChecks_a_BITS_62_TO_45_1_3_ULE_262139___d54 ||
	     capChecks_toCheck[37] &&
	     !capChecks_a_BITS_62_TO_45_1_EQ_capChecks_b_BIT_ETC___d58 ||
	     (!capChecks_toCheck[36] || capChecks_a[74]) &&
	     (!capChecks_toCheck[35] || capChecks_b[74]) &&
	     NOT_capChecks_toCheck_BIT_34_9_98_OR_capChecks_ETC___d304 ;
  assign capChecks_toCheck_BIT_29_9_AND_NOT_capChecks_b_ETC___d137 =
	     capChecks_toCheck[29] &&
	     !capChecks_b_BITS_159_TO_96_5_ULE_262139___d90 ||
	     capChecks_toCheck[27] &&
	     !_0_CONCAT_capChecks_a_BITS_81_TO_78_4_AND_capCh_ETC___d102 ||
	     capChecks_toCheck[26] &&
	     NOT_capChecks_a_BITS_43_TO_38_06_ULE_52_07_08__ETC___d124 ||
	     capChecks_toCheck[25] && capChecks_toCheck[11:6] != 6'd0 ||
	     capChecks_toCheck[22] && !capChecks_cap_exact ;
  assign capChecks_toCheck_BIT_29_9_AND_NOT_capChecks_b_ETC___d283 =
	     capChecks_toCheck[29] &&
	     !capChecks_b_BITS_159_TO_96_5_ULE_262139___d90 ||
	     (!capChecks_toCheck[27] ||
	      _0_CONCAT_capChecks_a_BITS_81_TO_78_4_AND_capCh_ETC___d102) &&
	     capChecks_toCheck[26] &&
	     NOT_capChecks_a_BITS_43_TO_38_06_ULE_52_07_08__ETC___d124 ;
  assign capChecks_toCheck_BIT_33_3_AND_capChecks_b_BIT_ETC___d259 =
	     capChecks_toCheck[33] && capChecks_b[67] ||
	     capChecks_toCheck[32] && !capChecks_b[75] ||
	     capChecks_toCheck[31] && !capChecks_b[73] ||
	     capChecks_toCheck[30] &&
	     !capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86 ||
	     capChecks_toCheck[29] &&
	     !capChecks_b_BITS_159_TO_96_5_ULE_262139___d90 ||
	     capChecks_toCheck[27] &&
	     !_0_CONCAT_capChecks_a_BITS_81_TO_78_4_AND_capCh_ETC___d102 ;
  assign capChecks_toCheck_BIT_34_9_AND_NOT_capChecks_a_ETC___d142 =
	     capChecks_toCheck[34] && !capChecks_a[67] ||
	     capChecks_toCheck[33] && capChecks_b[67] ||
	     capChecks_toCheck[32] && !capChecks_b[75] ||
	     capChecks_toCheck[31] && !capChecks_b[73] ||
	     capChecks_toCheck[30] &&
	     !capChecks_b_BITS_159_TO_96_5_EQ_0_CONCAT_capCh_ETC___d86 ||
	     capChecks_toCheck_BIT_29_9_AND_NOT_capChecks_b_ETC___d137 ;
  assign capChecks_toCheck_BIT_39_5_AND_capChecks_a_BIT_ETC___d150 =
	     capChecks_toCheck[39] && capChecks_a[162] &&
	     capChecks_a[62:45] != 18'd262143 &&
	     capChecks_a[62:45] != 18'd262142 ||
	     capChecks_toCheck[38] && capChecks_b[162] &&
	     capChecks_b[62:45] != 18'd262143 ||
	     capChecks_toCheck_BIT_43_7_AND_capChecks_a_BIT_ETC___d148 ;
  assign capChecks_toCheck_BIT_39_5_AND_capChecks_a_BIT_ETC___d298 =
	     capChecks_toCheck[39] && capChecks_a[162] &&
	     capChecks_a[62:45] != 18'd262143 &&
	     capChecks_a[62:45] != 18'd262142 ||
	     capChecks_toCheck[38] && capChecks_b[162] &&
	     capChecks_b[62:45] != 18'd262143 ||
	     capChecks_toCheck_BIT_43_7_AND_capChecks_a_BIT_ETC___d296 ;
  assign capChecks_toCheck_BIT_41_3_AND_capChecks_ddc_B_ETC___d152 =
	     capChecks_toCheck[41] && capChecks_ddc[162] &&
	     capChecks_ddc[62:45] != 18'd262143 ||
	     capChecks_toCheck[40] && capChecks_a[162] &&
	     capChecks_a[62:45] != 18'd262143 ||
	     capChecks_toCheck_BIT_39_5_AND_capChecks_a_BIT_ETC___d150 ;
  assign capChecks_toCheck_BIT_41_3_AND_capChecks_ddc_B_ETC___d300 =
	     capChecks_toCheck[41] && capChecks_ddc[162] &&
	     capChecks_ddc[62:45] != 18'd262143 ||
	     capChecks_toCheck[40] && capChecks_a[162] &&
	     capChecks_a[62:45] != 18'd262143 ||
	     capChecks_toCheck_BIT_39_5_AND_capChecks_a_BIT_ETC___d298 ;
  assign capChecks_toCheck_BIT_43_7_AND_capChecks_a_BIT_ETC___d148 =
	     capChecks_toCheck[43] &&
	     (capChecks_a[62:45] == 18'd262143 ||
	      capChecks_a[62:45] == 18'd262142 ||
	      capChecks_a[62:45] == 18'd262141 ||
	      capChecks_a[62:45] == 18'd262140) ||
	     capChecks_toCheck[42] &&
	     (capChecks_b[62:45] == 18'd262143 ||
	      capChecks_b[62:45] == 18'd262142 ||
	      capChecks_b[62:45] == 18'd262141 ||
	      capChecks_b[62:45] == 18'd262140) ||
	     capChecks_toCheck_BIT_28_2_AND_NOT_0_CONCAT_ca_ETC___d146 ;
  assign capChecks_toCheck_BIT_43_7_AND_capChecks_a_BIT_ETC___d296 =
	     capChecks_toCheck[43] &&
	     (capChecks_a[62:45] == 18'd262143 ||
	      capChecks_a[62:45] == 18'd262142 ||
	      capChecks_a[62:45] == 18'd262141 ||
	      capChecks_a[62:45] == 18'd262140) ||
	     capChecks_toCheck[42] &&
	     (capChecks_b[62:45] == 18'd262143 ||
	      capChecks_b[62:45] == 18'd262142 ||
	      capChecks_b[62:45] == 18'd262141 ||
	      capChecks_b[62:45] == 18'd262140) ;
endmodule  // module_capChecks

