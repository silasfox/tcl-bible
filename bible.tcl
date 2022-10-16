#!/usr/bin/env wish

package require Tk

variable content

proc K {a args} { set a }
proc SK* {f g v} { K [$f $v] [$g $v] }
proc o {f g args} { $f [$g $args] }
proc defalias {name body} { interp alias {} $name {} eval $body }

proc first list { lindex $list 0 }
proc rest list { lrange $list 1 end }
proc second list { lindex $list 1 }

defalias <handle { SK* read close }
defalias << { o <handle open }
proc >> {content filename} {
	proc pr {fh} "puts -nonewline \$fh \{$content\}"
	SK* pr close [open $filename w]
}

proc get-bible {name} {
	lmap v [split [<< "[file dirname $::argv0]/resources/$name.tsv"] "\n"] {
		string-to-verse $v
	}
}

proc string-to-verse {string} {
	set list [split $string "\t"]
	list {book} "[first $list]"\
		{chapter} "[lindex $list 3]"\
		{verse} "[lindex $list 4]"\
		{text} "[lindex $list 5]"
}

proc find-book {book args} {
	set res {}
	foreach verse $args {
		if {[regexp $book [dict get $verse book]]} {
			lappend res $verse
		}
	}
	set res
}

proc find-chapter {chapter args} {
	set res {}
	foreach verse $args {
		if {[dict get $verse chapter] eq $chapter} {
			lappend res $verse
		}
	}
	set res
}

proc find-reference {bible ref} {
	global content
	if [string is double [first $ref]] {
		defalias book [list find-book "^[first $ref] [second $ref]"]
		defalias chapter [list find-chapter [lindex $ref 2]]
	} else {
		defalias book [list find-book ^[first $ref]]
		defalias chapter [list find-chapter [second $ref]]
	}
	set content [o chapter book {*}$bible]
}

proc show-verse verse {
	.text.internal insert end "[dict get $verse verse]  [dict get $verse text]\n"
}

proc show verses {
	.text.internal delete 1.0 end
	lmap v $verses { show-verse $v }
}

text .text -font {{Times New Roman} 12}\
	-wrap word -padx 5 -pady 5
rename .text .text.internal

proc .text {args} {
	switch -exact -- [lindex $args 0] {
		insert {}
		delete {}
		replace {}
		default {
			return [eval .text.internal $args]
		}
	}
}

proc save-notes {filename} {
	>> [.notes get 1.0 end] $filename
}

defalias add-to-notes { .notes insert end }
defalias load-notes { o add-to-notes << }
proc load-notes {filename} {
	.notes insert end [<< $filename]
}

proc show-reference {bible} {
	show [find-reference [get-bible $bible] [.ref get]]
}

proc search-phrase {bible phrase} {
	global content
	set content {}
	foreach verse $bible {
		if [regexp $phrase [dict get $verse text]] {
			lappend content $verse
		}
	}
	set content
}

proc verse-to-latex verse {
	return \\textsuperscript\{[dict get $verse verse]\}[dict get $verse text]
}

proc to-latex chapter {
	return \\documentclass\{article\}\\usepackage\[a4paper]\{geometry\}\\usepackage\{setspace\}\\doublespacing\\begin\{document\}\\pagenumbering\{gobble\}\\begin\{center\}[join [lmap v $chapter {verse-to-latex $v}] "\n\n"]\\end\{center\}\\end\{document\}
}

proc result-counter {result} {
	global counter
	set res [llength $result]
	set counter "$res result[expr {$res==1?{}:{s}}]"
}

proc show-search {bible} {
	SK* result-counter show [search-phrase [get-bible $bible] [.search get]]
}

proc print-reference {bible} {
	set filename [tk_getSaveFile]
	>> [to-latex [find-reference [get-bible $bible] [.ref get]]] $filename.tex
	exec pdflatex $filename.tex
	exec zathura $filename.pdf &
}

proc sort-words {words} {
	set list '([lmap {word num} $words { list ( \"$word\" $num ) }])
	set guileStr "(display (sort $list (lambda (a b) (> (cadr a) (cadr b)))))"
	set guileStr [string map {\{ "" \} ""} $guileStr]
	return [string map {\( "" \) ""} [exec guile -c $guileStr]]
}

proc count-words {words} {
	set res {}
	foreach word $words {
		if {[catch { dict get $res $word }]} {
			dict set res $word 1
		} else {
			dict incr res $word
		}
	}
	set res
}

proc show-meta {} {
	global content
	.notes delete 1.0 end
	set count [sort-words [count-words [join [lmap v $content {dict get $v text}] " "]]]
	dict for {word count} $count {
		.notes insert end "$word: $count\n"
	}
}

entry .ref -font {{Times New Roman} 12}
button .get-ref -text "Show Reference"\
	-command { show-reference elb1871 }

entry .search -font {{Times New Roman} 12}
button .search-button -text "Find Phrase"\
	-command { show-search elb1871 }
button .meta-search -text "Lift Search"\
	-command { show-meta }

text .notes -font {{Times New Roman} 12} -wrap word -padx 5 -pady 5
button .save -text "Save Notes" \
	-command { save-notes [tk_getSaveFile -initialdir ~] }
button .load -text "Load Notes" \
	-command { load-notes [tk_getOpenFile -initialdir ~] }
button .print -text "Print Text" \
	-command { print-reference elb1871 }
label .counter -textvar counter

grid .text .notes -row 1
grid .ref .get-ref .text .notes .save .load .print .search .search-button .meta-search -padx 10 -pady 10
grid .ref .get-ref .text .notes .search .search-button .meta-search -stick nesw
grid .ref .get-ref .search .search-button .meta-search -row 0
grid .save .load .print -row 2
grid .ref .text -column 0
grid .text -columnspan 2
grid .get-ref -column 1
grid .notes .search -column 2
grid .notes -columnspan 3
grid .search-button -column 3
grid .meta-search -column 4

foreach w {.text .notes} {
	grid columnconfigure . $w -weight 1
	grid rowconfigure . $w -weight 1
}

foreach w {.counter .save .load .print} n {0 1 2 3} o {n ne nw n} {
	grid $w -column $n -stick $o
}
