#
# Test Loop Widget
#
# Author: Giuliano Zannetti <giuliano.zannetti@artgroup-spa.com>
#

divert(-1)

#
# Define N_TEST_LOOP - TEST_LOOP widget name macro
#

# E.g. N_TEST_LOOP = TEST_LOOP1.0 where '0' is passed through $1.

define(`N_TEST_LOOP', `TEST_LOOP'PIPELINE_ID`.'$1)

#
# Define W_TEST_LOOP - TEST_LOOP widget macro
#

# W_TEST_LOOP(
#     name,
#     format,
#     periods_sink,
#     periods_source,
#     core_id
# )

define(`W_TEST_LOOP',
`SectionVendorTuples."'N_TEST_LOOP($1)`_tuples_w" {'
`    tokens "sof_comp_tokens"'
`    tuples."word" {'
`            SOF_TKN_COMP_PERIOD_SINK_COUNT'         STR($3)
`            SOF_TKN_COMP_PERIOD_SOURCE_COUNT'       STR($4)
`            SOF_TKN_COMP_CORE_ID'                   STR($5)
`    }'
`}'
`SectionData."'N_TEST_LOOP($1)`_data_w" {'
`    tuples "'N_TEST_LOOP($1)`_tuples_w"'
`}'
`SectionVendorTuples."'N_TEST_LOOP($1)`_tuples_str" {'
`    tokens "sof_comp_tokens"'
`    tuples."string" {'
`            SOF_TKN_COMP_FORMAT'    STR($2)
`    }'
`}'
`SectionData."'N_TEST_LOOP($1)`_data_str" {'
`    tuples "'N_TEST_LOOP($1)`_tuples_str"'
`}'
`SectionVendorTuples."'N_TEST_LOOP($1)`_tuples_str_type" {'
`    tokens "sof_process_tokens"'
`    tuples."string" {'
`            SOF_TKN_PROCESS_TYPE'   "TESTLOOP"
`    }'
`}'
`SectionData."'N_TEST_LOOP($1)`_data_str_type" {'
`    tuples "'N_TEST_LOOP($1)`_tuples_str_type"'
`}'
`SectionWidget."'N_TEST_LOOP($1)`" {'
`    index "'PIPELINE_ID`"'
`    type "effect"'
`    no_pm "true"'
`    data ['
`            "'N_TEST_LOOP($1)`_data_w"'
`            "'N_TEST_LOOP($1)`_data_str"'
`            "'N_TEST_LOOP($1)`_data_str_type"'
`    ]'
`}')

divert(0)dnl