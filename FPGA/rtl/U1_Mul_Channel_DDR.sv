`timescale 1ns / 1ps 


module U1_Mul_Channel_DDR(
    
    //-----------------------------------------------------------------------------------
    // Clocks / resets
    // - `clk`            : local/system clock domain
    // - `ui_clk`         : DDR/MIG user interface clock domain
    // - `rst`            : reset for `clk` domain logic (active-high)
    // - `ui_clk_sync_rst`: reset synced to `ui_clk` domain (active-high)
    //-----------------------------------------------------------------------------------
    input                                       clk                         ,
    input                                       ui_clk                      ,
    input                                       rst                         ,
    input                                       ui_clk_sync_rst             ,
//---------------------------------------------------------------------------------------
// Local write interface (3 channels)
// Notes:
// - Channel index meaning is project-defined (in this repo typically: [0]=R, [1]=G, [2]=B).
// - `*_granted` indicates the request is accepted by the arbiter.
//---------------------------------------------------------------------------------------

    input                                       M_wr_req        [2:0]       ,// Local write request (per channel)
    output wire                                 M_wr_granted    [2:0]       ,// Local write grant/accept (per channel)
    output wire                                 M_wr_busy       [2:0]       ,// Local write busy (per channel)
    input                     [  31: 0]         M_wr_len        [2:0]       ,// Local write length (per channel, units defined by WR engine)
    input                     [  31: 0]         M_wr_addr       [2:0]       ,// Local write start address (per channel, byte address)
    input                     [  63: 0]         M_wr_din        [2:0]       ,// Local write data (per channel)
    input                                       M_wr_dval       [2:0]       ,// Local write data valid (per channel)
    input                                       M_wr_finish     [2:0]       ,// Local write finished (per channel)


//---------------------------------------------------------------------------------------
// Local read interface (3 channels)
//---------------------------------------------------------------------------------------


    input                                       M_rd_req        [2:0]       ,// Local read request (per channel)
    output wire                                 M_rd_granted    [2:0]       ,// Local read grant/accept (per channel)
    output wire                                 M_rd_busy       [2:0]       ,// Local read busy (per channel)
    input                     [  31: 0]         M_rd_addr       [2:0]       ,// Local read start address (per channel, byte address)
    input                     [  31: 0]         M_rd_lenth      [2:0]       ,// Local read length (per channel, bytes)
    output                    [  63: 0]         M_rd_dout       [2:0]       ,// Local read data (per channel)
    output wire                                 M_rd_dval       [2:0]       ,// Local read data valid (per channel)
    output wire                                 M_rd_finish     [2:0]       ,// Local read finished (per channel)

    //-----------------------------------------------------------------------------------
    // DDR interface (AXI4 Master)
    //-----------------------------------------------------------------------------------
  // Master Write Address
    output wire               [   5: 0]         M_AXI_AWID                  ,
    output wire               [  31: 0]         M_AXI_AWADDR                ,
    output wire               [   7: 0]         M_AXI_AWLEN                 ,
    output wire               [   2: 0]         M_AXI_AWSIZE                ,
    output wire               [   1: 0]         M_AXI_AWBURST               ,
    output wire                                 M_AXI_AWLOCK                ,
    output wire               [   3: 0]         M_AXI_AWCACHE               ,
    output wire               [   2: 0]         M_AXI_AWPROT                ,
    output wire               [   3: 0]         M_AXI_AWQOS                 ,
    output wire               [   1: 0]         M_AXI_AWUSER                ,
    output wire                                 M_AXI_AWVALID               ,
    input                                       M_AXI_AWREADY               ,
  // Master Write Data
    output wire               [ 255: 0]         M_AXI_WDATA                 ,
    output wire               [   7: 0]         M_AXI_WSTRB                 ,

    output wire                                 M_AXI_WLAST                 ,
    output wire               [   0: 0]         M_AXI_WUSER                 ,
    output wire                                 M_AXI_WVALID                ,
    input                                       M_AXI_WREADY                ,

  // Master Write Response
    input                     [   0: 0]         M_AXI_BID                   ,
    input                     [   1: 0]         M_AXI_BRESP                 ,
    input                     [   0: 0]         M_AXI_BUSER                 ,
    input                                       M_AXI_BVALID                ,
    output wire                                 M_AXI_BREADY                ,
    // Master Read Address
    output wire               [   5: 0]         M_AXI_ARID                  ,
    output wire               [  31: 0]         M_AXI_ARADDR                ,
    output wire               [   7: 0]         M_AXI_ARLEN                 ,
    output wire               [   2: 0]         M_AXI_ARSIZE                ,
    output wire               [   1: 0]         M_AXI_ARBURST               ,
    output wire                                 M_AXI_ARLOCK                ,
    output wire               [   3: 0]         M_AXI_ARCACHE               ,
    output wire               [   2: 0]         M_AXI_ARPROT                ,
    output wire               [   3: 0]         M_AXI_ARQOS                 ,
    output wire               [   1: 0]         M_AXI_ARUSER                ,
    output wire                                 M_AXI_ARVALID               ,
    input                                       M_AXI_ARREADY               ,
  // Master Read Data
    input                     [   3: 0]         M_AXI_RID                   ,
    input                     [ 255: 0]         M_AXI_RDATA                 ,
    input                     [   1: 0]         M_AXI_RRESP                 ,
    input                                       M_AXI_RLAST                 ,
    input                     [   0: 0]         M_AXI_RUSER                 ,
    input                                       M_AXI_RVALID                ,
    input                                       M_AXI_RREADY                 

    );


U1_0_Mul_Channel_DDR_Wr_channel u_U1_0_Mul_Channel_DDR_Wr_channel(
    .clk                                       (clk                        ),
    .ui_clk                                    (ui_clk                     ),
    .rst                                       (rst                        ),
    .ui_clk_sync_rst                           (ui_clk_sync_rst            ),

    .M_wr_req                                  (M_wr_req                   ),// Local write request (3 channels)
    .M_wr_granted                              (M_wr_granted               ),// Local write grant/accept (3 channels)
    .M_wr_busy                                 (M_wr_busy                  ),
    .M_wr_len                                  (M_wr_len                   ),// Local write length (3 channels)
    .M_wr_addr                                 (M_wr_addr                  ),// Local write address (3 channels)
    .M_wr_din                                  (M_wr_din                   ),// Local write data (3 channels)
    .M_wr_dval                                 (M_wr_dval                  ),// Local write data valid (3 channels)
    .M_wr_finish                               (M_wr_finish                ),// Local write finished (3 channels)
//---------------------------------------------------------------------------
// output AXI4_WR
//---------------------------------------------------------------------------
// Master Write Address
    .M_AXI_AWID                                (M_AXI_AWID                 ),
    .M_AXI_AWADDR                              (M_AXI_AWADDR               ),
    .M_AXI_AWLEN                               (M_AXI_AWLEN                ),
    .M_AXI_AWSIZE                              (M_AXI_AWSIZE               ),
    .M_AXI_AWBURST                             (M_AXI_AWBURST              ),
    .M_AXI_AWLOCK                              (M_AXI_AWLOCK               ),
    .M_AXI_AWCACHE                             (M_AXI_AWCACHE              ),
    .M_AXI_AWPROT                              (M_AXI_AWPROT               ),
    .M_AXI_AWQOS                               (M_AXI_AWQOS                ),
    .M_AXI_AWUSER                              (M_AXI_AWUSER               ),
    .M_AXI_AWVALID                             (M_AXI_AWVALID              ),
    .M_AXI_AWREADY                             (M_AXI_AWREADY              ),
// Master Write Data
    .M_AXI_WDATA                               (M_AXI_WDATA                ),
    .M_AXI_WSTRB                               (M_AXI_WSTRB                ),
    .M_AXI_WLAST                               (M_AXI_WLAST                ),
    .M_AXI_WUSER                               (M_AXI_WUSER                ),
    .M_AXI_WVALID                              (M_AXI_WVALID               ),
    .M_AXI_WREADY                              (M_AXI_WREADY               ),
// Master Write Response
    .M_AXI_BID                                 (M_AXI_BID                  ),
    .M_AXI_BRESP                               (M_AXI_BRESP                ),
    .M_AXI_BUSER                               (M_AXI_BUSER                ),
    .M_AXI_BVALID                              (M_AXI_BVALID               ),
    .M_AXI_BREADY                              (M_AXI_BREADY               ) 
);

//---------------------------------------------------------------------------------------
// RD
//---------------------------------------------------------------------------------------

U1_0_Mul_Channel_DDR_Rd_channel u_U1_0_Mul_Channel_DDR_Rd_channel(
    .clk                                       (clk                        ),
    .ui_clk                                    (ui_clk                     ),
    .rst                                       (rst                        ),
    .ui_clk_sync_rst                           (ui_clk_sync_rst            ),

    .M_rd_req                                  (M_rd_req                   ),// Local read request (3 channels)
    .M_rd_granted                              (M_rd_granted               ),// Local read grant/accept (3 channels)
    .M_rd_busy                                 (M_rd_busy                  ),// Local read busy (3 channels)
    .M_rd_len                                  (M_rd_lenth                 ),// Local read length (3 channels, bytes)
    .M_rd_addr                                 (M_rd_addr                  ),// Local read address (3 channels)
    .M_rd_dout                                 (M_rd_dout                  ),// Local read data (3 channels)
    .M_rd_dval                                 (M_rd_dval                  ),// Local read data valid (3 channels)
    .M_rd_finish                               (M_rd_finish                ),// Local read finished (3 channels)
//---------------------------------------------------------------------------
// output AXI4_RD
//---------------------------------------------------------------------------
// Master Read Address
    .M_AXI_ARID                                (M_AXI_ARID                 ),
    .M_AXI_ARADDR                              (M_AXI_ARADDR               ),
    .M_AXI_ARLEN                               (M_AXI_ARLEN                ),
    .M_AXI_ARSIZE                              (M_AXI_ARSIZE               ),
    .M_AXI_ARBURST                             (M_AXI_ARBURST              ),
    .M_AXI_ARLOCK                              (M_AXI_ARLOCK               ),
    .M_AXI_ARCACHE                             (M_AXI_ARCACHE              ),
    .M_AXI_ARPROT                              (M_AXI_ARPROT               ),
    .M_AXI_ARQOS                               (M_AXI_ARQOS                ),
    .M_AXI_ARUSER                              (M_AXI_ARUSER               ),
    .M_AXI_ARVALID                             (M_AXI_ARVALID              ),
    .M_AXI_ARREADY                             (M_AXI_ARREADY              ),
// Master Read Data
    .M_AXI_RID                                 (M_AXI_RID                  ),
    .M_AXI_RDATA                               (M_AXI_RDATA                ),
    .M_AXI_RRESP                               (M_AXI_RRESP                ),
    .M_AXI_RLAST                               (M_AXI_RLAST                ),
    .M_AXI_RUSER                               (M_AXI_RUSER                ),
    .M_AXI_RVALID                              (M_AXI_RVALID               ),
    .M_AXI_RREADY                              (M_AXI_RREADY               ) 
);





endmodule
