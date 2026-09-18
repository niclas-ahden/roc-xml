## The character rules of XML 1.0. Internal to the package.
Chars := [].{

	## The first character in `s` that XML cannot express, with the byte
	## offset where it starts.
	find_invalid_char : Str -> Try({ code_point : U32, byte_index : U64 }, [NoInvalidChar])
	find_invalid_char = |s|
		find_code_point(s, |code_point, _| !is_char(code_point))

	## The first character in `s` that an XML name cannot contain, with the
	## byte offset where it starts. An empty name passes, since it has no
	## character to point at.
	find_invalid_name_char : Str -> Try({ code_point : U32, byte_index : U64 }, [NoInvalidChar])
	find_invalid_name_char = |s|
		find_code_point(
			s,
			|code_point, is_first|
				if is_first {
					!is_name_start_char(code_point)
				} else {
					!is_name_char(code_point)
				},
		)

	## What to do with a character XML cannot express. The same type as
	## `Node.Replacement`, which is where it is documented.
	Replacement : [Drop, Replace(Str), ReplaceWith(U32 -> Str)]

	## `s` with every character XML cannot express dropped or replaced, as
	## `replacement` says. A replacement that itself holds such a character
	## has that character replaced by U+FFFD, so the result always passes
	## [find_invalid_char].
	replace_invalid : Str, Replacement -> Str
	replace_invalid = |s, replacement|
		if Chars.is_valid(s) {
			s
		} else {
			replace_invalid_bytes(
				s.to_utf8(),
				|code_point|
					match replacement {
						Drop => ""
						Replace(fixed) => fixed
						ReplaceWith(for_code_point) => for_code_point(code_point)
					},
			)
		}

	## `name` made into an XML name, so that it passes [is_name]. A character
	## a name cannot contain becomes `_`. A character a name can contain but
	## not start with, like a digit, gets a `_` in front, so nothing of it is
	## lost. An empty name becomes `_`.
	repair_name : Str -> Str
	repair_name = |name|
		if Chars.is_name(name) {
			name
		} else if name.is_empty() {
			"_"
		} else {
			repair_name_bytes(name.to_utf8())
		}

	## Whether `s` holds only characters XML can express, which is what
	## [find_invalid_char] finding nothing means. Most strings are answered
	## by their bytes alone: the control characters are single bytes, and the
	## only other two, U+FFFE and U+FFFF, start with 0xEF. So do harmless
	## characters, which is why that byte asks for the full answer.
	is_valid : Str -> Bool
	is_valid = |s|
		s.to_utf8().all(|byte| (byte >= 0x20 and byte != 0xEF) or byte == 0x9 or byte == 0xA or byte == 0xD)
			or Chars.find_invalid_char(s) == Err(NoInvalidChar)

	## Whether `s` is an XML name: not empty, and [find_invalid_name_char]
	## finds nothing. An ASCII name is answered by its bytes alone.
	is_name : Str -> Bool
	is_name = |s|
		match s.to_utf8() {
			[] => Bool.False
			[first, .. as rest] => {
				is_ascii_name = first < 0x80 and is_name_start_char(first.to_u32()) and rest.all(|byte| byte < 0x80 and is_name_char(byte.to_u32()))
				is_ascii_name or Chars.find_invalid_name_char(s) == Err(NoInvalidChar)
			}
		}
}

# Walk `bytes` character by character, copying the valid ones and replacing
# the rest.
replace_invalid_bytes : List(U8), (U32 -> Str) -> Str
replace_invalid_bytes = |bytes, replacement| {
	out = bytes.fold_with_index(
		List.with_capacity(bytes.len()),
		|acc, byte, index|
			if byte >= 0x80 and byte < 0xC0 {
				# A continuation byte, copied together with its lead byte
				acc
			} else {
				code_point = if byte < 0x80 {
					byte.to_u32()
				} else {
					code_point_at(bytes, index)
				}
				if is_char(code_point) {
					acc.concat(bytes.sublist({ start: index, len: utf8_len(byte) }))
				} else {
					acc.concat(safe_replacement(replacement(code_point)).to_utf8())
				}
			},
	)
	# Only whole characters were copied, so nothing is lost
	Str.from_utf8_lossy(out)
}

# Walk `bytes` character by character, copying what a name can hold there and
# writing `_` for the rest.
repair_name_bytes : List(U8) -> Str
repair_name_bytes = |bytes| {
	out = bytes.fold_with_index(
		List.with_capacity(bytes.len() + 1),
		|acc, byte, index|
			if byte >= 0x80 and byte < 0xC0 {
				# A continuation byte, copied together with its lead byte
				acc
			} else {
				code_point = if byte < 0x80 {
					byte.to_u32()
				} else {
					code_point_at(bytes, index)
				}
				whole = bytes.sublist({ start: index, len: utf8_len(byte) })
				if is_name_start_char(code_point) or (index > 0 and is_name_char(code_point)) {
					acc.concat(whole)
				} else if is_name_char(code_point) {
					# Fine in a name but not first, so it moves one step in
					acc.append('_').concat(whole)
				} else {
					acc.append('_')
				}
			},
	)
	# Only whole characters and `_` were written, so nothing is lost
	Str.from_utf8_lossy(out)
}

# The replacement with any character XML cannot express turned into U+FFFD.
safe_replacement : Str -> Str
safe_replacement = |s|
	if Chars.is_valid(s) {
		s
	} else {
		replace_invalid_bytes(s.to_utf8(), |_| "\u(FFFD)")
	}

# How many bytes the character starting with `lead` takes.
utf8_len : U8 -> U64
utf8_len = |lead|
	if lead < 0x80 {
		1
	} else if lead < 0xE0 {
		2
	} else if lead < 0xF0 {
		3
	} else {
		4
	}

# The first code point in `s` for which `reject` holds, with the byte offset
# where it starts. `reject` also learns whether the code point is the first
# in the string.
find_code_point : Str, (U32, Bool -> Bool) -> Try({ code_point : U32, byte_index : U64 }, [NoInvalidChar])
find_code_point = |s, reject| {
	bytes = s.to_utf8()
	bytes.fold_with_index_until(
		Err(NoInvalidChar),
		|state, byte, index|
			if byte >= 0x80 and byte < 0xC0 {
				# A continuation byte, already covered by its lead byte
				Continue(state)
			} else {
				code_point = if byte < 0x80 {
					byte.to_u32()
				} else {
					code_point_at(bytes, index)
				}
				if reject(code_point, index == 0) {
					Break(Ok({ code_point, byte_index: index }))
				} else {
					Continue(state)
				}
			},
	)
}

# Decode the code point whose lead byte sits at `index`. Roc strings are valid
# UTF-8, so the continuation bytes are there and carry six payload bits each.
code_point_at : List(U8), U64 -> U32
code_point_at = |bytes, index| {
	byte_at = |i| bytes.get(i).ok_or(0).to_u32()
	lead = byte_at(index)
	if lead < 0x80 {
		lead
	} else if lead < 0xE0 {
		(lead - 0xC0) * 0x40 + (byte_at(index + 1) - 0x80)
	} else if lead < 0xF0 {
		(lead - 0xE0) * 0x1000 + (byte_at(index + 1) - 0x80) * 0x40 + (byte_at(index + 2) - 0x80)
	} else {
		(lead - 0xF0) * 0x40000 + (byte_at(index + 1) - 0x80) * 0x1000 + (byte_at(index + 2) - 0x80) * 0x40 + (byte_at(index + 3) - 0x80)
	}
}

# The `Char` production of XML 1.0. Surrogates are excluded, but a Roc string
# cannot hold them anyway. ASCII, which is most of what passes through, is
# answered here, and the ranges hold the rest.
is_char : U32 -> Bool
is_char = |cp|
	if cp < 0x80 {
		cp >= 0x20 or cp == 0x9 or cp == 0xA or cp == 0xD
	} else {
		in_ranges(cp, char_ranges)
	}

# `Char` beyond ASCII.
char_ranges : List((U32, U32))
char_ranges = [
	(0x80, 0xD7FF),
	(0xE000, 0xFFFD),
	(0x10000, 0x10FFFF),
]

# The `NameStartChar` production of XML 1.0. ASCII is answered here, and the
# ranges hold the rest.
is_name_start_char : U32 -> Bool
is_name_start_char = |cp|
	if cp < 0x80 {
		(cp >= 'a' and cp <= 'z') or (cp >= 'A' and cp <= 'Z') or cp == '_' or cp == ':'
	} else {
		in_ranges(cp, name_start_ranges)
	}

# The `NameChar` production of XML 1.0. ASCII is answered here, and the ranges
# hold the rest.
is_name_char : U32 -> Bool
is_name_char = |cp|
	if cp < 0x80 {
		is_name_start_char(cp) or (cp >= '0' and cp <= '9') or cp == '-' or cp == '.'
	} else {
		in_ranges(cp, name_start_ranges) or in_ranges(cp, name_extra_ranges)
	}

# `NameStartChar` beyond ASCII.
name_start_ranges : List((U32, U32))
name_start_ranges = [
	(0xC0, 0xD6),
	(0xD8, 0xF6),
	(0xF8, 0x2FF),
	(0x370, 0x37D),
	(0x37F, 0x1FFF),
	(0x200C, 0x200D),
	(0x2070, 0x218F),
	(0x2C00, 0x2FEF),
	(0x3001, 0xD7FF),
	(0xF900, 0xFDCF),
	(0xFDF0, 0xFFFD),
	(0x10000, 0xEFFFF),
]

# What `NameChar` allows on top of `NameStartChar`, beyond ASCII.
name_extra_ranges : List((U32, U32))
name_extra_ranges = [
	(0xB7, 0xB7),
	(0x300, 0x36F),
	(0x203F, 0x2040),
]

# Whether `cp` falls inside any of the inclusive ranges.
in_ranges : U32, List((U32, U32)) -> Bool
in_ranges = |cp, ranges|
	ranges.any(|(low, high)| cp >= low and cp <= high)

# Nothing to find in a clean string
expect Chars.find_invalid_char("fine") == Err(NoInvalidChar)
expect Chars.find_invalid_char("Héllo 世界 🎉") == Err(NoInvalidChar)

# Tab, newline and carriage return are the control characters XML allows
expect Chars.find_invalid_char("a\tb\nc\rd") == Err(NoInvalidChar)

# DEL, the C1 range, U+FFFD and the top of the supplementary planes are all allowed
expect Chars.find_invalid_char("\u(7F)\u(80)\u(9F)\u(FFFD)\u(10FFFF)") == Err(NoInvalidChar)

# The first invalid character is reported, at its byte offset
expect Chars.find_invalid_char("a\u(0)") == Ok({ code_point: 0, byte_index: 1 })
expect Chars.find_invalid_char("ab\u(2)cd\u(3)") == Ok({ code_point: 2, byte_index: 2 })

# The byte index counts bytes, not characters
expect Chars.find_invalid_char("é\u(1)") == Ok({ code_point: 1, byte_index: 2 })

# U+FFFE and U+FFFF are the two non-characters XML forbids
expect Chars.find_invalid_char("a\u(FFFE)") == Ok({ code_point: 0xFFFE, byte_index: 1 })
expect Chars.find_invalid_char("\u(FFFF)") == Ok({ code_point: 0xFFFF, byte_index: 0 })

# A name cannot start with a digit, hyphen or period, but may contain them
expect Chars.find_invalid_name_char("h1.a-b_c") == Err(NoInvalidChar)
expect Chars.find_invalid_name_char("1st") == Ok({ code_point: '1', byte_index: 0 })
expect Chars.find_invalid_name_char("-x") == Ok({ code_point: '-', byte_index: 0 })
expect Chars.find_invalid_name_char(".x") == Ok({ code_point: '.', byte_index: 0 })

# Markup characters and spaces cannot appear in a name
expect Chars.find_invalid_name_char("bad tag") == Ok({ code_point: ' ', byte_index: 3 })
expect Chars.find_invalid_name_char("a<b") == Ok({ code_point: '<', byte_index: 1 })
expect Chars.find_invalid_name_char("x=y") == Ok({ code_point: '=', byte_index: 1 })

# The rest of ASCII is not a name character, DEL and the C1 range included
expect Chars.find_invalid_name_char("a\u(7F)") == Ok({ code_point: 0x7F, byte_index: 1 })
expect Chars.find_invalid_name_char("a\u(80)") == Ok({ code_point: 0x80, byte_index: 1 })
expect Chars.find_invalid_name_char("a/b") == Ok({ code_point: '/', byte_index: 1 })
expect Chars.find_invalid_name_char("a@b") == Ok({ code_point: '@', byte_index: 1 })

# The middle dot is a name character, but not a start character
expect Chars.find_invalid_name_char("a\u(B7)") == Err(NoInvalidChar)
expect Chars.find_invalid_name_char("\u(B7)a") == Ok({ code_point: 0xB7, byte_index: 0 })

# Namespace prefixes and non-ASCII letters are legal in names
expect Chars.find_invalid_name_char("xmlns:r") == Err(NoInvalidChar)
expect Chars.find_invalid_name_char("café") == Err(NoInvalidChar)
expect Chars.find_invalid_name_char("日本") == Err(NoInvalidChar)

# A letter outside the Basic Multilingual Plane may start a name, and a
# combining mark may follow but not start one
expect Chars.find_invalid_name_char("\u(20000)a\u(300)") == Err(NoInvalidChar)
expect Chars.find_invalid_name_char("\u(300)a") == Ok({ code_point: 0x300, byte_index: 0 })

# An empty name has no character to point at
expect Chars.find_invalid_name_char("") == Err(NoInvalidChar)

# A clean string is left alone, whatever the replacement
expect Chars.replace_invalid("fine", Drop) == "fine"
expect Chars.replace_invalid("fine", Replace("?")) == "fine"

# Every bad character is dropped, or replaced by a string or by what a function returns for it
expect Chars.replace_invalid("a\u(0)b\u(7)", Drop) == "ab"
expect Chars.replace_invalid("a\u(0)b\u(7)", Replace("?")) == "a?b?"
expect Chars.replace_invalid("a\u(0)b\u(7)", ReplaceWith(|code_point| "<${code_point.to_str()}>")) == "a<0>b<7>"

# Dropping can leave nothing
expect Chars.replace_invalid("\u(0)\u(FFFE)", Drop) == ""

# Characters around a replaced one survive whole, whatever their length
expect Chars.replace_invalid("é\u(1)日🎉", Replace("_")) == "é_日🎉"
expect Chars.replace_invalid("é\u(1)日🎉", Drop) == "é日🎉"

# A replacement that is itself invalid is made harmless
expect Chars.replace_invalid("\u(0)", Replace("\u(1)x")) == "\u(FFFD)x"
expect Chars.replace_invalid("\u(0)", ReplaceWith(|_| "\u(1)x")) == "\u(FFFD)x"

# What replacing returns always passes the check
expect
	["a\u(0)", "\u(FFFF)é\u(1B)", "\u(0)\u(1)\u(2)"].all(
		|s| Chars.is_valid(Chars.replace_invalid(s, Drop)) and Chars.is_valid(Chars.replace_invalid(s, Replace("\u(0)"))),
	)

# A name that is one already is left alone
expect Chars.repair_name("h1.a-b_c") == "h1.a-b_c"
expect Chars.repair_name("xmlns:r") == "xmlns:r"
expect Chars.repair_name("café") == "café"

# What a name cannot contain becomes `_`
expect Chars.repair_name("bad tag") == "bad_tag"
expect Chars.repair_name("a<b=\"c\"") == "a_b__c_"
expect Chars.repair_name("a\u(0)b") == "a_b"
expect Chars.repair_name(" ") == "_"

# What a name can contain but not start with gets `_` in front
expect Chars.repair_name("1st") == "_1st"
expect Chars.repair_name("-x") == "_-x"
expect Chars.repair_name(".x") == "_.x"
expect Chars.repair_name("\u(B7)a") == "_\u(B7)a"
expect Chars.repair_name("\u(300)a") == "_\u(300)a"

# Only the first character is treated that way
expect Chars.repair_name("1 2") == "_1_2"

# Characters of any length survive whole around a repaired one
expect Chars.repair_name("日 本🎉") == "日_本🎉"
expect Chars.repair_name("\u(20000) a") == "\u(20000)_a"

# An empty name becomes `_`
expect Chars.repair_name("") == "_"

# What repairing returns is always a name
expect
	["", " ", "1st", "-", "bad tag", "a<b", "\u(0)", "🎉", "é\u(7)", "\u(B7)", "x=y\"z'"].all(
		|name| Chars.is_name(Chars.repair_name(name)),
	)

# Decoding covers every UTF-8 length
expect code_point_at("a".to_utf8(), 0) == 'a'
expect code_point_at("é".to_utf8(), 0) == 0xE9
expect code_point_at("日".to_utf8(), 0) == 0x65E5
expect code_point_at("🎉".to_utf8(), 0) == 0x1F389
expect code_point_at("aé".to_utf8(), 1) == 0xE9

# The quick answers agree with the full ones
expect Chars.is_valid("") and Chars.is_valid("fine") and Chars.is_valid("a\tb\nc\rd")
expect Chars.is_valid("Héllo 世界 🎉") and Chars.is_valid("\u(7F)\u(80)\u(9F)\u(FFFD)\u(10FFFF)")

# U+FF01 shares its first byte with U+FFFE and U+FFFF, and is fine
expect Chars.is_valid("\u(FF01)")
expect !Chars.is_valid("a\u(0)") and !Chars.is_valid("é\u(1)") and !Chars.is_valid("a\u(FFFE)") and !Chars.is_valid("\u(FFFF)")

expect Chars.is_name("a") and Chars.is_name("h1.a-b_c") and Chars.is_name("xmlns:r") and Chars.is_name("café") and Chars.is_name("日本")
expect Chars.is_name("a\u(B7)") and Chars.is_name("\u(20000)a\u(300)")
expect !Chars.is_name("") and !Chars.is_name("1st") and !Chars.is_name("-x") and !Chars.is_name("bad tag") and !Chars.is_name("a<b")
expect !Chars.is_name("a\u(7F)") and !Chars.is_name("\u(B7)a") and !Chars.is_name("\u(300)a") and !Chars.is_name("café!")
