#!/data/data/com.termux/files/usr/bin/bash

cat <<'CONTRACT'
=== TOOL CONTRACTS ===

check_app
ARG: package name
EXAMPLE: com.shopee.foody.driver.th
PURPOSE: ตรวจว่าแอปทำงานอยู่หรือไม่

get_app_state
ARG: NONE
PURPOSE: ตรวจสถานะแอป/connection โดยใช้ package ที่กำหนดไว้ใน tool

get_ram
ARG: NONE
PURPOSE: ตรวจข้อมูล RAM

get_logcat
ARG: number of lines
EXAMPLE: 100
LIMIT: tool caps lines at 200
PURPOSE: ดึง logcat จำนวนบรรทัดที่ระบุ

apk_search
ARG: subcommand + arguments
SUPPORTED SUBCOMMANDS:
  method_exists <class.method>
  interface_callers <interface.method>
  caller <class.method>
  callee <class.method>
  chain <class.method> [depth]
  call_graph <class.method> [depth]
NOTE: interface_impl is a separate tool.
PURPOSE: ค้นข้อมูลจาก classes4.dex ตาม subcommand

method_exists
ARG: class.method
FORMAT: Lclass/name.method
EXAMPLE: Lcom/test/Example.run

caller
ARG: class.method
FORMAT: Lclass/name.method
EXAMPLE: Lcom/test/Example.run

callee
ARG: class.method
FORMAT: Lclass/name.method
EXAMPLE: Lcom/test/Example.run

interface_callers
ARG: interface.method
FORMAT: Linterface/name.method
EXAMPLE: Lcom/test/ExampleInterface.run

list_methods
ARG: Lclass/name or Lclass/name;
EXAMPLE: Lb50/a$a
PURPOSE: แสดง methods ที่ประกาศจริงใน class จาก DEX เพื่อให้ Planner ได้ method เป็น Evidence ก่อนเรียก callee

interface_impl
ARG: interface
FORMAT: Linterface/name; OR Linterface/name
EXAMPLE: Lcom/test/ExampleInterface;

call_graph
ARG: class.method [depth]
FORMAT: Lclass/name.method OR Lclass/name.method|depth
EXAMPLE: Lcom/test/A.run
EXAMPLE: Lcom/test/A.run|2
LIMIT: tool caps depth at 3

graph_parse
ARG: graph data
PURPOSE: parse graph output containing Lgz/ nodes/edges

read_file
ARG: file path under ~/ai-tools/
EXAMPLE: ~/ai-tools/result.txt

read_range
ARG: FILE|START|END
FILE must be under ~/ai-tools/
EXAMPLE: ~/ai-tools/result.txt|1|100

search_file
ARG: FILE|PATTERN
FILE must be under ~/ai-tools/
EXAMPLE: ~/ai-tools/result.txt|caller

list_tools
ARG: NONE
PURPOSE: แสดงรายการ tools จาก Controller รุ่นปัจจุบัน

=== RULES ===
1. ห้ามใช้ ARG=target หรือ ARG=TARGET
2. ห้ามสร้าง class/method/package/path ที่ไม่มีใน Evidence หรือ TARGET
3. ต้องใช้รูปแบบ ARG ตาม Contract
4. หากไม่มี ARG ที่ถูกต้อง ให้ TOOL: NONE
5. ห้ามทำซ้ำ TOOL+ARG เดิม
6. Contract เป็นข้อกำหนดรูปแบบคำสั่ง ไม่ใช่ Evidence
CONTRACT
