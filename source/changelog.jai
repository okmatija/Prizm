PRIZM_VERSION_BACKLOGGED :: App.Version.{"0.8.0", "WIP", #string DONE
DONE};

PRIZM_VERSION_1_0_0 :: App.Version.{"1.0.0", "WIP", #string DONE
DONE};

PRISM_VERSION_0_7_1 :: App.Version.{"0.7.1", "28 September 2023", #string DONE
DONE};

PRISM_VERSION_0_7_0 :: App.Version.{"0.7.0", "08 August 2023", #string DONE
DONE};

PRISM_VERSION_0_6_1 :: App.Version.{"0.6.1", "23 July 2023", #string DONE
DONE};

PRISM_VERSION_0_6_0 :: App.Version.{"0.6.0", "10 May 2023", #string DONE
DONE};

PRISM_VERSION_0_5_1 :: App.Version.{"0.5.1", "17 Feburary 2023", #string DONE
DONE};

PRISM_VERSION_0_5_0 :: App.Version.{"0.5.0", "15 January 2023", #string DONE
DONE
};

PRISM_VERSION_0_4_0 :: App.Version.{"0.4.0", "06 October 2022", #string DONE
DONE
};

PRISM_VERSION_0_3_1 :: App.Version.{"0.3.1", "22 September 2022", #string DONE
DONE
};

PRISM_VERSION_0_3_0 :: App.Version.{"0.3.0", "06 September 2022", #string DONE
DONE
};

PRISM_VERSION_0_2_3 :: App.Version.{"0.2.3", "26 May 2022", #string DONE
DONE
};

PRISM_VERSION_0_2_2 :: App.Version.{"0.2.2", "18 May 2022", #string DONE
DONE
};

PRISM_VERSION_0_2_1 :: App.Version.{"0.2.1", "27 March 2022", #string DONE
DONE
};

PRISM_VERSION_0_2_0 :: App.Version.{"0.2.0", "15 March 2022", #string DONE
DONE
};

PRISM_VERSION_0_1_2 :: App.Version.{"0.1.2", "04 January 2022", #string DONE
DONE
};

PRISM_VERSION_0_1_1 :: App.Version.{"0.1.1", "01 December 2021", #string DONE
DONE
};

PRISM_VERSION_0_1_0 :: App.Version.{"0.1.0", "20 October 2021", #string DONE
DONE
};

init_changelog :: () {
    //array_add(*app.changelog, PRIZM_VERSION_BACKLOGGED);
    array_add(*app.changelog, PRIZM_VERSION_1_0_0);
    array_add(*app.changelog, PRISM_VERSION_0_7_1);
    array_add(*app.changelog, PRISM_VERSION_0_7_0);
    array_add(*app.changelog, PRISM_VERSION_0_6_1);
    array_add(*app.changelog, PRISM_VERSION_0_6_0);
    array_add(*app.changelog, PRISM_VERSION_0_5_1);
    array_add(*app.changelog, PRISM_VERSION_0_5_0);
    array_add(*app.changelog, PRISM_VERSION_0_4_0);
    array_add(*app.changelog, PRISM_VERSION_0_3_1);
    array_add(*app.changelog, PRISM_VERSION_0_3_0);
    array_add(*app.changelog, PRISM_VERSION_0_2_2);
    array_add(*app.changelog, PRISM_VERSION_0_2_1);
    array_add(*app.changelog, PRISM_VERSION_0_2_0);
    array_add(*app.changelog, PRISM_VERSION_0_1_2);
    array_add(*app.changelog, PRISM_VERSION_0_1_1);
    array_add(*app.changelog, PRISM_VERSION_0_1_0);
}
