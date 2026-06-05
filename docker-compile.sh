
echo "compiling with yohimik amxmod compiler"


docker run --rm --platform linux/386 \
#   -v /Users/philipdaquin/Desktop/cs1.6/extracted-addons-from-yohimik-docker/amxmodx/scripting:/compiler \
#   -v /Users/philipdaquin/Desktop/cs1.6/cs-server-2/cs-web-server-metpamx/addons/amxmodx/scripting:/scripting \
  -v /amxmodx/scripting:/compiler \
  -v /amxmodx/scripting:/scripting \
  -w /scripting \
  debian:trixie-slim \
  sh -c 'cp /compiler/amxxpc /tmp/amxxpc && cp /compiler/amxxpc32.so /tmp/amxxpc32.so && chmod +x /tmp/amxxpc && /tmp/amxxpc nst_source/NST_ZbClass_Heavy.sma -i/scripting/include -ocompiled/NST_ZbClass_Heavy.amxx'