#!/bin/sh

echo $(dirname $0)

# bh bisort em3d health mst perimeter power treeadd tsp utils voronoi
for PROG in bh bisort em3d health perimeter power treeadd tsp
do
	echo "Building olden benchmark $(dirname $0)/$PROG"
	cd $(dirname $0)/$PROG
	make GFE_TARGET=$1 clean
	make GFE_TARGET=$1 RUNS=$2
	cp main.elf ../$PROG.elf
	make GFE_TARGET=$1 clean
	echo '`-> Done'
done


