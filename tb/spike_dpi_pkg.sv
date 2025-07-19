package spike_dpi_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ------------------------------------------------------------------------
  // DPI-C imports
  // ------------------------------------------------------------------------
  import "DPI-C" context function void    spike_setup                   (input longint argc,
                                                                         input string  argv);
  import "DPI-C" context function void    start_execution               ();
  import "DPI-C" context function void    do_step                       (input longint unsigned n);
  import "DPI-C" context function int     exit_code                     ();
  import "DPI-C" context function longint unsigned spike_get_pc         (input int unsigned hart);
  import "DPI-C" context function longint unsigned spike_dump_registers (input int unsigned hart);
  import "DPI-C" context function longint unsigned spike_dump_csrs      (input int unsigned hart);

  import "DPI-C" context function int     get_memory_data          (output longint data,
                                                                    input  longint addr);
  import "DPI-C" context function int     set_memory_data          (input  longint data,
                                                                    input  longint addr,
                                                                    input  int     size);

  import "DPI-C" context function void    spike_set_external_interrupt (input  longint mip);
  import "DPI-C" context function longint unsigned address_translate   (input  longint virtual_addr,
                                                                        input  longint len,
                                                                        input  int     acc_type,
                                                                        input  longint satp,
                                                                        input  longint priv_lvl,
                                                                        input  longint mstatus,
                                                                        output longint exc);

  // ------------------------------------------------------------------------
  // ISS wrapper
  // ------------------------------------------------------------------------
  class spike_iss extends uvm_component;
    `uvm_component_utils(spike_iss)

    protected int exit_code_q;

    function new(string name = "spike_iss", uvm_component parent = null);
      super.new(name, parent);
    endfunction : new

    // --------------------------------------------------------------------
    // Configuration helpers
    // --------------------------------------------------------------------
    string plusargs = "";
    int    argc     = 0;

    function void build_phase (uvm_phase phase);
      //-------------------------------------------------------------
      //  Declarations – must precede statements
      //-------------------------------------------------------------
      string raw;          // original +arg value
      string tokens[$];    // queue that will hold the split tokens
      int    idx;          // token counter
      //-------------------------------------------------------------
      super.build_phase(phase);
      // Extract the +SPIKE_ARGS=<arg1:arg2:...> string, if present
      if ($value$plusargs("SPIKE_ARGS=%s", raw)) begin : parse_plusargs
        // UVM‑1.1d helper: split on ':' and put the pieces in 'tokens'
        uvm_split_string(raw, ":", tokens);
    
        // Report each token
        foreach (tokens[idx]) begin
          `uvm_info("PLUSARGS",
                    $sformatf("token[%0d] = %s", idx, tokens[idx]),
                    UVM_LOW)
        end
      end
    endfunction : build_phase


    // --------------------------------------------------------------------
    // Run helpers
    // --------------------------------------------------------------------
    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      start_execution();

      // Poll until Spike reports a non-zero exit code
      do begin
        do_step(1000);
        // TODO: hook coverage or callbacks here
      end while (is_active());

      phase.drop_objection(this);
    endtask : run_phase

    function bit is_active();
      int ec;
      ec = exit_code();
      if (ec !== exit_code_q) begin
        `uvm_info(get_type_name(),
                  $sformatf("Spike halted with exit=%0d", ec),
                  UVM_LOW)
        exit_code_q = ec;
      end
      return (ec == 0); // 0 → still running
    endfunction : is_active

    // --------------------------------------------------------------------
    // Memory utilities (examples)
    // --------------------------------------------------------------------
    function longint load64(longint addr);
      longint data;
      if (get_memory_data(data, addr))
        `uvm_error(get_type_name(), $sformatf("MMU read failed @%h", addr))
      return data;
    endfunction : load64

    function void store64(longint addr, longint data);
      if (set_memory_data(data, addr, 64))
        `uvm_error(get_type_name(), $sformatf("MMU write failed @%h", addr))
    endfunction : store64
  endclass : spike_iss

endpackage : spike_dpi_pkg
