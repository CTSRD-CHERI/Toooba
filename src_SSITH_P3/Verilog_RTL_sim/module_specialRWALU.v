//
// Generated by Bluespec Compiler, version 2019.05.beta2 (build a88bf40db, 2019-05-24)
//
// On Mon Jun 29 23:31:31 BST 2020
//
//
// Ports:
// Name                         I/O  size props
// specialRWALU                   O   163
// specialRWALU_cap               I   163
// specialRWALU_oldCap            I   163
// specialRWALU_scrType           I     5
//
// Combinational paths from inputs to outputs:
//   (specialRWALU_cap,
//    specialRWALU_oldCap,
//    specialRWALU_scrType) -> specialRWALU
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

module module_specialRWALU(specialRWALU_cap,
			   specialRWALU_oldCap,
			   specialRWALU_scrType,
			   specialRWALU);
  // value method specialRWALU
  input  [162 : 0] specialRWALU_cap;
  input  [162 : 0] specialRWALU_oldCap;
  input  [4 : 0] specialRWALU_scrType;
  output [162 : 0] specialRWALU;

  // signals for module outputs
  wire [162 : 0] specialRWALU;

  // remaining internal signals
  reg [65 : 0] IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d168;
  reg [63 : 0] IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35;
  reg [13 : 0] CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q1;
  reg [4 : 0] CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q3;
  reg [2 : 0] CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q5,
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8;
  reg CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q2,
      CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q4,
      CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q6;
  wire [71 : 0] IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_IF_ETC___d207;
  wire [65 : 0] IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d169,
		in__h1130,
		in__h393,
		res_capFat_address__h1799,
		x__h1148,
		x__h411,
		y__h1147,
		y__h410;
  wire [63 : 0] SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95,
		addBase__h1869,
		addBase__h2053,
		bot__h1872,
		bot__h2056,
		offsetAddr__h130,
		offsetAddr__h1389,
		offsetAddr__h696,
		offsetAddr__h992,
		oldOffset__h23,
		x__h1048,
		x__h1050,
		x__h1267,
		x__h1516,
		x__h284,
		x__h286,
		x__h565,
		x__h870,
		y__h767;
  wire [49 : 0] highOffsetBits__h1393,
		highOffsetBits__h700,
		mask__h1962,
		mask__h2146,
		signBits__h1390,
		signBits__h697,
		x__h1420,
		x__h727;
  wire [15 : 0] newAddrBits__h1671,
		newAddrBits__h1705,
		newAddrBits__h1739,
		newAddrBits__h1773,
		offset__h1036,
		offset__h272,
		x__h1926,
		x__h2110;
  wire [13 : 0] IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d192,
		IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d198,
		IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d178,
		IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d184,
		IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d201,
		res_capFat_addrBits__h1800,
		toBoundsM1__h1403,
		toBoundsM1__h710,
		toBounds__h1402,
		toBounds__h709;
  wire [9 : 0] IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d282,
	       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_NO_ETC___d284,
	       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d283;
  wire [5 : 0] IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d281;
  wire [4 : 0] IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d265,
	       IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d277;
  wire [3 : 0] IF_specialRWALU_oldCap_BITS_37_TO_35_11_ULT_sp_ETC___d225,
	       IF_specialRWALU_oldCap_BITS_37_TO_35_11_ULT_sp_ETC___d239;
  wire [2 : 0] repBound__h2681, repBound__h2703;
  wire IF_IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0__ETC___d56,
       IF_IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0__ETC___d75,
       IF_SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO__ETC___d116,
       IF_SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO__ETC___d134,
       IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d255,
       IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d267,
       IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d215,
       IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d229,
       IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d63,
       IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d78,
       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_NO_ETC___d144,
       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d143,
       NOT_specialRWALU_cap_BITS_43_TO_38_8_ULT_50_18___d119,
       NOT_specialRWALU_oldCap_BITS_43_TO_38_3_ULT_50_8___d59,
       SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d123,
       SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d139,
       specialRWALU_cap_BITS_23_TO_21_43_ULT_specialR_ETC___d251,
       specialRWALU_cap_BITS_37_TO_35_47_ULT_specialR_ETC___d248,
       specialRWALU_oldCap_BITS_23_TO_21_09_ULT_speci_ETC___d213,
       specialRWALU_oldCap_BITS_37_TO_35_11_ULT_speci_ETC___d212;

  // value method specialRWALU
  assign specialRWALU =
	     { IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_NO_ETC___d144,
	       res_capFat_address__h1799,
	       res_capFat_addrBits__h1800,
	       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_IF_ETC___d207,
	       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_NO_ETC___d284 } ;

  // remaining internal signals
  assign IF_IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0__ETC___d56 =
	     IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35[63] ?
	       x__h565[13:0] >= toBounds__h709 :
	       x__h565[13:0] <= toBoundsM1__h710 ;
  assign IF_IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0__ETC___d75 =
	     IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35[63] ?
	       x__h870[13:0] >= toBounds__h709 :
	       x__h870[13:0] <= toBoundsM1__h710 ;
  assign IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d281 =
	     { CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q2,
	       CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q3 } ;
  assign IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d282 =
	     { CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q5,
	       CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q6,
	       IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d281 } ;
  assign IF_SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO__ETC___d116 =
	     SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95[63] ?
	       x__h1267[13:0] >= toBounds__h1402 :
	       x__h1267[13:0] <= toBoundsM1__h1403 ;
  assign IF_SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO__ETC___d134 =
	     SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95[63] ?
	       x__h1516[13:0] >= toBounds__h1402 :
	       x__h1516[13:0] <= toBoundsM1__h1403 ;
  assign IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d192 =
	     (specialRWALU_cap[43:38] == 6'd52) ?
	       { 1'b0, newAddrBits__h1739[12:0] } :
	       newAddrBits__h1739[13:0] ;
  assign IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d198 =
	     (specialRWALU_cap[43:38] == 6'd52) ?
	       { 1'b0, newAddrBits__h1773[12:0] } :
	       newAddrBits__h1773[13:0] ;
  assign IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d255 =
	     IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d192[13:11] <
	     repBound__h2703 ;
  assign IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d265 =
	     { IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d255,
	       (specialRWALU_cap_BITS_37_TO_35_47_ULT_specialR_ETC___d248 ==
		IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d255) ?
		 2'd0 :
		 ((specialRWALU_cap_BITS_37_TO_35_47_ULT_specialR_ETC___d248 &&
		   !IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d255) ?
		    2'd1 :
		    2'd3),
	       (specialRWALU_cap_BITS_23_TO_21_43_ULT_specialR_ETC___d251 ==
		IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d255) ?
		 2'd0 :
		 ((specialRWALU_cap_BITS_23_TO_21_43_ULT_specialR_ETC___d251 &&
		   !IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d255) ?
		    2'd1 :
		    2'd3) } ;
  assign IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d267 =
	     IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d198[13:11] <
	     repBound__h2703 ;
  assign IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d277 =
	     { IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d267,
	       (specialRWALU_cap_BITS_37_TO_35_47_ULT_specialR_ETC___d248 ==
		IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d267) ?
		 2'd0 :
		 ((specialRWALU_cap_BITS_37_TO_35_47_ULT_specialR_ETC___d248 &&
		   !IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d267) ?
		    2'd1 :
		    2'd3),
	       (specialRWALU_cap_BITS_23_TO_21_43_ULT_specialR_ETC___d251 ==
		IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d267) ?
		 2'd0 :
		 ((specialRWALU_cap_BITS_23_TO_21_43_ULT_specialR_ETC___d251 &&
		   !IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d267) ?
		    2'd1 :
		    2'd3) } ;
  assign IF_specialRWALU_oldCap_BITS_37_TO_35_11_ULT_sp_ETC___d225 =
	     { (specialRWALU_oldCap_BITS_37_TO_35_11_ULT_speci_ETC___d212 ==
		IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d215) ?
		 2'd0 :
		 ((specialRWALU_oldCap_BITS_37_TO_35_11_ULT_speci_ETC___d212 &&
		   !IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d215) ?
		    2'd1 :
		    2'd3),
	       (specialRWALU_oldCap_BITS_23_TO_21_09_ULT_speci_ETC___d213 ==
		IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d215) ?
		 2'd0 :
		 ((specialRWALU_oldCap_BITS_23_TO_21_09_ULT_speci_ETC___d213 &&
		   !IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d215) ?
		    2'd1 :
		    2'd3) } ;
  assign IF_specialRWALU_oldCap_BITS_37_TO_35_11_ULT_sp_ETC___d239 =
	     { (specialRWALU_oldCap_BITS_37_TO_35_11_ULT_speci_ETC___d212 ==
		IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d229) ?
		 2'd0 :
		 ((specialRWALU_oldCap_BITS_37_TO_35_11_ULT_speci_ETC___d212 &&
		   !IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d229) ?
		    2'd1 :
		    2'd3),
	       (specialRWALU_oldCap_BITS_23_TO_21_09_ULT_speci_ETC___d213 ==
		IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d229) ?
		 2'd0 :
		 ((specialRWALU_oldCap_BITS_23_TO_21_09_ULT_speci_ETC___d213 &&
		   !IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d229) ?
		    2'd1 :
		    2'd3) } ;
  assign IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d178 =
	     (specialRWALU_oldCap[43:38] == 6'd52) ?
	       { 1'b0, newAddrBits__h1671[12:0] } :
	       newAddrBits__h1671[13:0] ;
  assign IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d184 =
	     (specialRWALU_oldCap[43:38] == 6'd52) ?
	       { 1'b0, newAddrBits__h1705[12:0] } :
	       newAddrBits__h1705[13:0] ;
  assign IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d215 =
	     IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d178[13:11] <
	     repBound__h2681 ;
  assign IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d229 =
	     IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d184[13:11] <
	     repBound__h2681 ;
  assign IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d63 =
	     (highOffsetBits__h700 == 50'd0 &&
	      IF_IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0__ETC___d56 ||
	      NOT_specialRWALU_oldCap_BITS_43_TO_38_3_ULT_50_8___d59) &&
	     specialRWALU_oldCap[62:45] == 18'd262143 ;
  assign IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d78 =
	     (highOffsetBits__h700 == 50'd0 &&
	      IF_IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0__ETC___d75 ||
	      NOT_specialRWALU_oldCap_BITS_43_TO_38_3_ULT_50_8___d59) &&
	     specialRWALU_oldCap[62:45] == 18'd262143 ;
  assign IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_IF_ETC___d207 =
	     (specialRWALU_scrType[4:2] == 3'd0 ||
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd0 ||
	      specialRWALU_scrType[4:2] == 3'd1 ||
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd1) ?
	       specialRWALU_oldCap[81:10] :
	       specialRWALU_cap[81:10] ;
  assign IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_NO_ETC___d144 =
	     (specialRWALU_scrType[4:2] == 3'd0 ||
	      specialRWALU_scrType[4:2] != 3'd1 &&
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd0) ?
	       IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d63 &&
	       specialRWALU_oldCap[162] :
	       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d143 ;
  assign IF_specialRWALU_scrType_BITS_4_TO_2_EQ_0_OR_NO_ETC___d284 =
	     (specialRWALU_scrType[4:2] == 3'd0 ||
	      specialRWALU_scrType[4:2] != 3'd1 &&
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd0) ?
	       { repBound__h2681,
		 specialRWALU_oldCap_BITS_37_TO_35_11_ULT_speci_ETC___d212,
		 specialRWALU_oldCap_BITS_23_TO_21_09_ULT_speci_ETC___d213,
		 IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d215,
		 IF_specialRWALU_oldCap_BITS_37_TO_35_11_ULT_sp_ETC___d225 } :
	       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d283 ;
  assign IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d143 =
	     (specialRWALU_scrType[4:2] == 3'd1 ||
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd1) ?
	       IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d78 &&
	       specialRWALU_oldCap[162] :
	       CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q4 ;
  assign IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d169 =
	     (specialRWALU_scrType[4:2] == 3'd1 ||
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd1) ?
	       { 2'd0, bot__h1872 } + { 2'd0, offsetAddr__h696 } :
	       IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d168 ;
  assign IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d201 =
	     (specialRWALU_scrType[4:2] == 3'd1 ||
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd1) ?
	       IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d184 :
	       CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q1 ;
  assign IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d283 =
	     (specialRWALU_scrType[4:2] == 3'd1 ||
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd1) ?
	       { repBound__h2681,
		 specialRWALU_oldCap_BITS_37_TO_35_11_ULT_speci_ETC___d212,
		 specialRWALU_oldCap_BITS_23_TO_21_09_ULT_speci_ETC___d213,
		 IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d229,
		 IF_specialRWALU_oldCap_BITS_37_TO_35_11_ULT_sp_ETC___d239 } :
	       IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d282 ;
  assign NOT_specialRWALU_cap_BITS_43_TO_38_8_ULT_50_18___d119 =
	     specialRWALU_cap[43:38] >= 6'd50 ;
  assign NOT_specialRWALU_oldCap_BITS_43_TO_38_3_ULT_50_8___d59 =
	     specialRWALU_oldCap[43:38] >= 6'd50 ;
  assign SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d123 =
	     (highOffsetBits__h1393 == 50'd0 &&
	      IF_SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO__ETC___d116 ||
	      NOT_specialRWALU_cap_BITS_43_TO_38_8_ULT_50_18___d119) &&
	     specialRWALU_cap[62:45] == 18'd262143 ;
  assign SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d139 =
	     (highOffsetBits__h1393 == 50'd0 &&
	      IF_SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO__ETC___d134 ||
	      NOT_specialRWALU_cap_BITS_43_TO_38_8_ULT_50_18___d119) &&
	     (specialRWALU_cap[62:45] == 18'd262143 ||
	      !SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95[0]) ;
  assign SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95 =
	     x__h1048 | in__h1130[63:0] ;
  assign addBase__h1869 =
	     { {48{x__h1926[15]}}, x__h1926 } << specialRWALU_oldCap[43:38] ;
  assign addBase__h2053 =
	     { {48{x__h2110[15]}}, x__h2110 } << specialRWALU_cap[43:38] ;
  assign bot__h1872 =
	     { specialRWALU_oldCap[159:110] & mask__h1962, 14'd0 } +
	     addBase__h1869 ;
  assign bot__h2056 =
	     { specialRWALU_cap[159:110] & mask__h2146, 14'd0 } +
	     addBase__h2053 ;
  assign highOffsetBits__h1393 = x__h1420 & mask__h2146 ;
  assign highOffsetBits__h700 = x__h727 & mask__h1962 ;
  assign in__h1130 = specialRWALU_cap[161:96] & y__h1147 ;
  assign in__h393 = specialRWALU_oldCap[161:96] & y__h410 ;
  assign mask__h1962 = 50'h3FFFFFFFFFFFF << specialRWALU_oldCap[43:38] ;
  assign mask__h2146 = 50'h3FFFFFFFFFFFF << specialRWALU_cap[43:38] ;
  assign newAddrBits__h1671 =
	     { 2'd0, specialRWALU_oldCap[23:10] } + { 2'd0, x__h565[13:0] } ;
  assign newAddrBits__h1705 =
	     { 2'd0, specialRWALU_oldCap[23:10] } + { 2'd0, x__h870[13:0] } ;
  assign newAddrBits__h1739 =
	     { 2'd0, specialRWALU_cap[23:10] } + { 2'd0, x__h1267[13:0] } ;
  assign newAddrBits__h1773 =
	     { 2'd0, specialRWALU_cap[23:10] } + { 2'd0, x__h1516[13:0] } ;
  assign offsetAddr__h130 =
	     { IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35[63:2],
	       1'd0,
	       IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35[0] } ;
  assign offsetAddr__h1389 =
	     { SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95[63:1],
	       1'd0 } ;
  assign offsetAddr__h696 =
	     { IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35[63:1],
	       1'd0 } ;
  assign offsetAddr__h992 =
	     { SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95[63:2],
	       1'd0,
	       SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95[0] } ;
  assign offset__h1036 = { 2'd0, specialRWALU_cap[95:82] } - x__h2110 ;
  assign offset__h272 = { 2'd0, specialRWALU_oldCap[95:82] } - x__h1926 ;
  assign oldOffset__h23 = x__h284 | in__h393[63:0] ;
  assign repBound__h2681 = specialRWALU_oldCap[23:21] - 3'b001 ;
  assign repBound__h2703 = specialRWALU_cap[23:21] - 3'b001 ;
  assign res_capFat_addrBits__h1800 =
	     (specialRWALU_scrType[4:2] == 3'd0 ||
	      specialRWALU_scrType[4:2] != 3'd1 &&
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd0) ?
	       IF_specialRWALU_oldCap_BITS_43_TO_38_3_EQ_52_7_ETC___d178 :
	       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d201 ;
  assign res_capFat_address__h1799 =
	     (specialRWALU_scrType[4:2] == 3'd0 ||
	      specialRWALU_scrType[4:2] != 3'd1 &&
	      IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 ==
	      3'd0) ?
	       { 2'd0, bot__h1872 } + { 2'd0, offsetAddr__h130 } :
	       IF_specialRWALU_scrType_BITS_4_TO_2_EQ_1_OR_IF_ETC___d169 ;
  assign signBits__h1390 =
	     {50{SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95[63]}} ;
  assign signBits__h697 =
	     {50{IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35[63]}} ;
  assign specialRWALU_cap_BITS_23_TO_21_43_ULT_specialR_ETC___d251 =
	     specialRWALU_cap[23:21] < repBound__h2703 ;
  assign specialRWALU_cap_BITS_37_TO_35_47_ULT_specialR_ETC___d248 =
	     specialRWALU_cap[37:35] < repBound__h2703 ;
  assign specialRWALU_oldCap_BITS_23_TO_21_09_ULT_speci_ETC___d213 =
	     specialRWALU_oldCap[23:21] < repBound__h2681 ;
  assign specialRWALU_oldCap_BITS_37_TO_35_11_ULT_speci_ETC___d212 =
	     specialRWALU_oldCap[37:35] < repBound__h2681 ;
  assign toBoundsM1__h1403 = { 3'b110, ~specialRWALU_cap[20:10] } ;
  assign toBoundsM1__h710 = { 3'b110, ~specialRWALU_oldCap[20:10] } ;
  assign toBounds__h1402 = 14'd14336 - { 3'b0, specialRWALU_cap[20:10] } ;
  assign toBounds__h709 = 14'd14336 - { 3'b0, specialRWALU_oldCap[20:10] } ;
  assign x__h1048 = x__h1050 << specialRWALU_cap[43:38] ;
  assign x__h1050 = { {48{offset__h1036[15]}}, offset__h1036 } ;
  assign x__h1148 = 66'h3FFFFFFFFFFFFFFFF << specialRWALU_cap[43:38] ;
  assign x__h1267 = offsetAddr__h992 >> specialRWALU_cap[43:38] ;
  assign x__h1420 =
	     SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d95[63:14] ^
	     signBits__h1390 ;
  assign x__h1516 = offsetAddr__h1389 >> specialRWALU_cap[43:38] ;
  assign x__h1926 = { specialRWALU_oldCap[1:0], specialRWALU_oldCap[23:10] } ;
  assign x__h2110 = { specialRWALU_cap[1:0], specialRWALU_cap[23:10] } ;
  assign x__h284 = x__h286 << specialRWALU_oldCap[43:38] ;
  assign x__h286 = { {48{offset__h272[15]}}, offset__h272 } ;
  assign x__h411 = 66'h3FFFFFFFFFFFFFFFF << specialRWALU_oldCap[43:38] ;
  assign x__h565 = offsetAddr__h130 >> specialRWALU_oldCap[43:38] ;
  assign x__h727 =
	     IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35[63:14] ^
	     signBits__h697 ;
  assign x__h870 = offsetAddr__h696 >> specialRWALU_oldCap[43:38] ;
  assign y__h1147 = ~x__h1148 ;
  assign y__h410 = ~x__h411 ;
  assign y__h767 = ~specialRWALU_cap[159:96] ;
  always@(specialRWALU_scrType)
  begin
    case (specialRWALU_scrType[4:2])
      3'd2, 3'd3:
	  IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 =
	      specialRWALU_scrType[4:2];
      default: IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 = 3'd4;
    endcase
  end
  always@(specialRWALU_scrType or
	  oldOffset__h23 or y__h767 or specialRWALU_cap)
  begin
    case (specialRWALU_scrType[1:0])
      2'd0:
	  IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35 =
	      specialRWALU_cap[159:96];
      2'd1:
	  IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35 =
	      oldOffset__h23 | specialRWALU_cap[159:96];
      default: IF_specialRWALU_scrType_BITS_1_TO_0_2_EQ_0_3_T_ETC___d35 =
		   oldOffset__h23 & y__h767;
    endcase
  end
  always@(IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 or
	  specialRWALU_cap or
	  bot__h2056 or offsetAddr__h992 or offsetAddr__h1389)
  begin
    case (IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8)
      3'd2:
	  IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d168 =
	      { 2'd0, bot__h2056 } + { 2'd0, offsetAddr__h992 };
      3'd3:
	  IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d168 =
	      { 2'd0, bot__h2056 } + { 2'd0, offsetAddr__h1389 };
      default: IF_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_ETC___d168 =
		   specialRWALU_cap[161:96];
    endcase
  end
  always@(IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 or
	  specialRWALU_cap or
	  IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d192 or
	  IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d198)
  begin
    case (IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8)
      3'd2:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q1 =
	      IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d192;
      3'd3:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q1 =
	      IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d198;
      default: CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q1 =
		   specialRWALU_cap[95:82];
    endcase
  end
  always@(IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 or
	  specialRWALU_cap or
	  specialRWALU_cap_BITS_23_TO_21_43_ULT_specialR_ETC___d251)
  begin
    case (IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8)
      3'd2, 3'd3:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q2 =
	      specialRWALU_cap_BITS_23_TO_21_43_ULT_specialR_ETC___d251;
      default: CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q2 =
		   specialRWALU_cap[5];
    endcase
  end
  always@(IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 or
	  specialRWALU_cap or
	  IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d265 or
	  IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d277)
  begin
    case (IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8)
      3'd2:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q3 =
	      IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d265;
      3'd3:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q3 =
	      IF_specialRWALU_cap_BITS_43_TO_38_8_EQ_52_85_T_ETC___d277;
      default: CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q3 =
		   specialRWALU_cap[4:0];
    endcase
  end
  always@(IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 or
	  specialRWALU_cap or
	  SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d123 or
	  SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d139)
  begin
    case (IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8)
      3'd2:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q4 =
	      SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d123 &&
	      specialRWALU_cap[162];
      3'd3:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q4 =
	      SEXT__0_CONCAT_specialRWALU_cap_BITS_95_TO_82__ETC___d139 &&
	      specialRWALU_cap[162];
      default: CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q4 =
		   specialRWALU_cap[162];
    endcase
  end
  always@(IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 or
	  specialRWALU_cap or repBound__h2703)
  begin
    case (IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8)
      3'd2, 3'd3:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q5 =
	      repBound__h2703;
      default: CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q5 =
		   specialRWALU_cap[9:7];
    endcase
  end
  always@(IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8 or
	  specialRWALU_cap or
	  specialRWALU_cap_BITS_37_TO_35_47_ULT_specialR_ETC___d248)
  begin
    case (IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2_OR_sp_ETC___d8)
      3'd2, 3'd3:
	  CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q6 =
	      specialRWALU_cap_BITS_37_TO_35_47_ULT_specialR_ETC___d248;
      default: CASE_IF_specialRWALU_scrType_BITS_4_TO_2_EQ_2__ETC__q6 =
		   specialRWALU_cap[6];
    endcase
  end
endmodule  // module_specialRWALU

