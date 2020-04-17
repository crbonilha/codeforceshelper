
param(
    $round,
    $round_id
)


# check parameters
if ($null -eq $round) {
    Write-Host "Please specify the round number."
    exit
}
if ($null -eq $round_id) {
    Write-Host "Please specify the round id (check the contest URL)."
    exit
}
if (!(Test-Path ./$round)) {
    $x = New-Item -Path ./ `
    -Name "$round" `
    -ItemType "directory"
    $x = $x
}


Write-Host "Fetching contest page."
$page = Invoke-WebRequest "https://codeforces.com/contest/$round_id"
$table = $page.ParsedHtml.getElementsByClassName("problems")[0]
$table_rows = $table.getElementsByTagName("tr")
# iterate over the problems
for ($index=1; $index -lt $table_rows.Length(); $index++) {
    $tr = $table_rows[$index]

    $tds = $tr.getElementsByTagName("td")
    $letter_column = $tds[0]
    $letter_inner_text = $letter_column.innerText.Trim()

    # create io files
    Write-Host "Creating files for $letter_inner_text."
    if (!(Test-Path ./$round/$letter_inner_text.in)) {
        $x = New-Item -Path ./$round `
        -Name "$letter_inner_text.in" `
        -ItemType "File"
        $x = $x
    }
    Clear-Content ./$round/$letter_inner_text.in

    if (!(Test-Path ./$round/$letter_inner_text.sol)) {
        $x = New-Item -Path ./$round `
        -Name "$letter_inner_text.sol" `
        -ItemType "File"
        $x = $x
    }
    Clear-Content ./$round/$letter_inner_text.sol

    # fetch io from the problem page
    Write-Host "Fetching page $letter_inner_text."
    $problem_page = Invoke-WebRequest "https://codeforces.com/contest/$round_id/problem/$letter_inner_text"
    $sample_tests = $problem_page.ParsedHtml.getElementsByClassName("sample-test")
    foreach ($sample_test in $sample_tests) {
        $input_section = $sample_test.getElementsByClassName("input")[0]
        $input = $input_section.getElementsByTagName("pre")[0].innerText
        "$input" > ./$round/$letter_inner_text.in

        $output_section = $sample_test.getElementsByClassName("output")[0]
        $output = $output_section.getElementsByTagName("pre")[0].innerText
        "$output" > ./$round/$letter_inner_text.sol
    }
}

Write-Host "Done."
