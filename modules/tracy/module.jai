// Based on modules/Iprof, but adapted for the Tracy compiler.

#module_parameters(IMPORT_MODE := Import_Mode.METAPROGRAM, ENABLED := true) {
    Import_Mode :: enum u8 {
        METAPROGRAM :: 0;
        CLIENT      :: 1;
    }
}


#if IMPORT_MODE == .METAPROGRAM {
    // When being imported by a metaprogram, we provide code for instrumenting the target program,
    // including the Metaprogram_Plugin interface.

    #load "instrument.jai";
    #load "options.jai";
}
#load "runtime.jai";
