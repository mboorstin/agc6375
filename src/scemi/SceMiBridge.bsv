import SceMi::*;

import SceMiHarness::*;

// Hook it up to the appropriate transport method
(* synthesize *)
module mkSceMiBridge ();
    // TODO: Parameterize the TCP hardcode
   Empty scemi <- buildSceMi(mkSceMiHarness, SCEMI);
endmodule
