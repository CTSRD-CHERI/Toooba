// 2018, Alexandre Joannou, University of Cambridge

// Wrapper for the Altera module based on the documentation found here:
// https://www.altera.com/content/dam/altera-www/global/en_US/pdfs/literature/ug/ug_ram_rom.pdf
// Needed as the Bluespec provided BRAM2BELoad module does not work on quartus.
////////////////////////////////////////////////////////////////////////////////

module BlueUtils_BRAM2 (
  CLK,
  // port A
  en_a,
  wen_a,
  address_a,
  data_a,
  q_a,
  // port B
  en_b,
  wen_b,
  address_b,
  data_b,
  q_b
);

  // ports
  input CLK;
  // port A
  input en_a;
  input [(width_a/8)-1:0] wen_a;
  input [widthad_a-1:0] address_a;
  input [width_a-1:0] data_a;
  output [width_a-1:0] q_a;
  // port B
  input en_b;
  input [(width_b/8)-1:0]wen_b;
  input [widthad_b-1:0] address_b;
  input [width_b-1:0] data_b;
  output [width_b-1:0] q_b;

  // parameters
  // port A
  parameter widthad_a = 1;
  parameter address_reg_a = "CLOCK0";
  parameter width_a = 1;
  parameter numwords_a = 1;
  parameter width_byteena_a = 1;
  parameter byteena_reg_a = "CLOCK0";
  parameter outdata_reg_a = "UNREGISTERED";
  parameter outdata_aclr_a = "NONE";
  parameter clock_enable_input_a = "BYPASS";
  parameter clock_enable_output_a = "BYPASS";
  parameter read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ";
  // port B
  parameter widthad_b = 1;
  parameter address_reg_b = "CLOCK0";
  parameter width_b = 1;
  parameter numwords_b = 1;
  parameter width_byteena_b = 1;
  parameter byteena_reg_b = "CLOCK0";
  parameter outdata_reg_b = "UNREGISTERED";
  parameter outdata_aclr_b = "NONE";
  parameter clock_enable_input_b = "BYPASS";
  parameter clock_enable_output_b = "BYPASS";
  parameter read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ";
  // others
  parameter byte_size = 8;
  parameter ram_block_type = "AUTO";
  parameter read_during_write_mode_mixed_ports = "OLD_DATA";
  parameter init_file = "UNUSED";
  parameter init_file_layout = "PORT_A";
  parameter indata_reg_b = "CLOCK0";
  parameter lpm_type = "altsyncram";
  parameter operation_mode = "BIDIR_DUAL_PORT";
  parameter power_up_uninitialized = "FALSE";
  parameter wrcontrol_wraddress_reg_b = "CLOCK0";

  /*TODO
  .address_aclr_a(address_aclr_a),
  .address_aclr_b(address_aclr_b),
  .ram_block_type(ram_block_type),
  .maximum_depth(maximum_depth),
  .clock_enable_core_a(clock_enable_core_a),
  .clock_enable_core_b(clock_enable_core_b),
  .enable_ecc(enable_ecc),
  .width_eccstatus(width_eccstatus)
  */
  altsyncram#(
    // port A
    .widthad_a(widthad_a),
    .address_reg_a(address_reg_a),
    .width_a(width_a),
    .width_byteena_a(width_byteena_a),
    .byteena_reg_a(byteena_reg_a),
    .outdata_reg_a(outdata_reg_a),
    .outdata_aclr_a(outdata_aclr_a),
    .numwords_a(numwords_a),
    .clock_enable_input_a(clock_enable_input_a),
    .clock_enable_output_a(clock_enable_output_a),
    .read_during_write_mode_port_a(read_during_write_mode_port_a),
    // port B
    .widthad_b(widthad_b),
    .address_reg_b(address_reg_b),
    .width_b(width_b),
    .width_byteena_b(width_byteena_b),
    .byteena_reg_b(byteena_reg_b),
    .outdata_reg_b(outdata_reg_b),
    .outdata_aclr_b(outdata_aclr_b),
    .numwords_b(numwords_b),
    .clock_enable_input_b(clock_enable_input_b),
    .clock_enable_output_b(clock_enable_output_b),
    .read_during_write_mode_port_b(read_during_write_mode_port_b),
    // others
    .ram_block_type(ram_block_type),
    .byte_size(byte_size),
    .init_file(init_file),
    .init_file_layout(init_file_layout),
    .indata_reg_b(indata_reg_b),
    .lpm_type(lpm_type),
    .operation_mode(operation_mode),
    .power_up_uninitialized(power_up_uninitialized),
    .read_during_write_mode_mixed_ports(read_during_write_mode_mixed_ports),
    .wrcontrol_wraddress_reg_b(wrcontrol_wraddress_reg_b)
  ) mem (
    // port A
    .rden_a (en_a),
    .wren_a (en_a & |wen_a),
    .addressstall_a (1'b0),
    .address_a (address_a),
    .data_a (data_a),
    .byteena_a (wen_a),
    .q_a (q_a),
    // port B
    .rden_b (en_b),
    .wren_b (en_b & |wen_b),
    .addressstall_b (1'b0),
    .address_b (address_b),
    .data_b (data_b),
    .byteena_b (wen_b),
    .q_b (q_b),
    // others
    .clock0 (CLK),
    .clock1 (1'b1),
    .aclr0 (1'b0),
    .aclr1 (1'b0),
    .clocken0 (1'b1),
    .clocken1 (1'b1),
    .clocken2 (1'b1),
    .clocken3 (1'b1)
  );

endmodule
