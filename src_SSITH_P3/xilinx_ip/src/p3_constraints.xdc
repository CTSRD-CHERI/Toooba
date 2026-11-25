set_property MARK_DEBUG true [get_nets jtagtap/CLK_jtag_tclk_out]
create_clock -period 40.000 -name tck_internal -waveform {0.000 20.000} [get_nets jtagtap/CLK_jtag_tclk_out]
set_clock_uncertainty 2.00 [get_clocks *tck_internal*]

# Preserve only the ObjID buffer's new synthesis boundary. Internal logic
# remains available for optimisation. Quiet permits older exported RTL.
set_property -quiet KEEP_HIERARCHY yes [get_cells -quiet -hierarchical -filter {REF_NAME == mkObjIdBuffer || ORIG_REF_NAME == mkObjIdBuffer}]
