
param (
    $round,
    $round_id,
    [switch]$setup = $false,
    $problem
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
if (!(Test-Path ./$round/io)) {
    $x = New-Item -Path ./$round `
    -Name "io" `
    -ItemType "directory"
    $x = $x
}


function Write-To-File {
    param (
        $path,
        $file_name,
        $content
    )

    $full_path = "$path/$file_name"
    if (!(Test-Path $full_path)) {
        $x = New-Item -Path "$path" `
        -Name "$file_name" `
        -ItemType "File"
        $x = $x
    }

    Clear-Content $full_path
    "$content" > $full_path
}


# setup
if ($setup -eq $true) {
    Write-Host "Fetching contest page."
    $page = Invoke-WebRequest "https://codeforces.com/contest/$round_id"
    $table = $page.ParsedHtml.getElementsByClassName("problems")[0]
    $table_rows = $table.getElementsByTagName("tr")

    # iterate over the problems
    for ($problem_index=1; $problem_index -lt $table_rows.Length(); $problem_index++) {
        $tr = $table_rows[$problem_index]

        $tds = $tr.getElementsByTagName("td")
        $letter_column = $tds[0]
        $letter_inner_text = $letter_column.innerText.Trim().ToLower()

        Write-Host "Creating files for $letter_inner_text."

        # create cpp files
        if (!(Test-Path ./$round/$letter_inner_text.cpp)) {
            Copy-Item template.cpp ./$round/$letter_inner_text.cpp
        }

        # fetch io from the problem page
        Write-Host "Fetching page $letter_inner_text."
        $problem_page = Invoke-WebRequest "https://codeforces.com/contest/$round_id/problem/$letter_inner_text"
        $sample_test = $problem_page.ParsedHtml.getElementsByClassName("sample-test")[0]
        for ($sample_index = 0; ; $sample_index++) {
            $input_section = $sample_test.getElementsByClassName("input")[$sample_index]
            if ($null -eq $input_section) {
                break
            }
            $input = $input_section.getElementsByTagName("pre")[0].innerText
            Write-To-File -path "./$round/io" `
            -file_name "$letter_inner_text.$sample_index.in" `
            -content "$input"

            $output_section = $sample_test.getElementsByClassName("output")[$sample_index]
            $output = $output_section.getElementsByTagName("pre")[0].innerText
            Write-To-File -path "./$round/io" `
            -file_name "$letter_inner_text.$sample_index.sol" `
            -content "$output"
        }
    }
}


# validate
if ($null -ne $problem) {
    if (!(Test-Path ./$round/$problem.cpp)) {
        Write-Host "The problem $problem.cpp doesn't exist."
        exit
    }

    # compiling solution
    Write-Host "Compiling $problem.cpp."
    g++ ./$round/$problem.cpp -o ./$round/$problem.exe

    # running against the input files
    for ($sample_index = 0; ; $sample_index++) {
        if (!(Test-Path ./$round/io/$problem.$sample_index.in)) {
            break
        }

        if (!(Test-Path ./$round/io/$problem.$sample_index.out)) {
            $x = New-Item -Path ./$round/io `
            -Name "$problem.$sample_index.out" `
            -ItemType "file"
            $x = $x
        }
        Clear-Content ./$round/io/$problem.$sample_index.out

        Write-Host "Running test case $sample_index. " -NoNewline
        Get-Content ./$round/io/$problem.$sample_index.in | `
        & ./$round/$problem.exe > ./$round/io/$problem.$sample_index.out

        $out = Get-Content -Path ./$round/io/$problem.$sample_index.out
        $diff = $null
        if ($null -ne $out) {
            $diff = Compare-Object `
            -ReferenceObject (Get-Content -Path ./$round/io/$problem.$sample_index.sol) `
            -DifferenceObject $out `
            -CaseSensitive
        }

        if ($null -eq $out) {
            Write-Host "Solution didn't print." -ForegroundColor "Red"
        } elseif ($null -eq $diff) {
            Write-Host "Passed." -ForegroundColor "Green"
        } else {
            Write-Host "Not passed." -ForegroundColor "Red"
            foreach ($d in $diff) {
                $color = "Yellow"
                if ($d.SideIndicator -eq "<=") { # solution
                    $color = "Green"
                } elseif ($d.SideIndicator -eq "=>") { # my output
                    $color = "Red"
                }

                $row = $d.InputObject
                Write-Host "$row" -ForegroundColor "$color"
            }
        }
    }
}


Write-Host "Done."
