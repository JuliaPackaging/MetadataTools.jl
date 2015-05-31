######################################################################
# This file:
# (c) Alain Lichnewsky, 2015
# Licensed under the MIT License

%.pdf:%.dot
	ddot $<
%.jpg:%.pdf
	tojpg $<


DOTTARGETS=dotImgs/tp1_Cairo.pdf  \
           dotImgs/tp1_Cairo_rev.pdf\
           dotImgs/tp1_GLAbstraction.pdf  \
           dotImgs/tp2_all.pdf  \
           dotImgs/tp2_GLAbstraction.pdf\
           dotImgs/tp2_Quaternions.pdf  \
           dotImgs/tp2_Romeo.pdf

JPGTARGETS= dotImgs/tp1_Cairo.jpg  \
           dotImgs/tp1_Cairo_rev.jpg\
           dotImgs/tp1_GLAbstraction.jpg  \
           dotImgs/tp2_all.jpg  \
           dotImgs/tp2_GLAbstraction.jpg\
           dotImgs/tp2_Quaternions.jpg  \
           dotImgs/tp2_Romeo.jpg

.PHONY: all jpgs pdfs testCmd testCmd1 testCmd2 

jpgs:  $(JPGTARGETS)

pdfs: $(DOTTARGETS) 

testCmd1:
	Julia4 ../src/MetaRegInfo.jl --dot dotImgs/A1.dot --pkg=Cairo
	Julia4 ../src/MetaRegInfo.jl --rev --dot dotImgs/A1rev.dot --pkg=Cairo
	Julia4 ../src/MetaRegInfo.jl  -i --dot dotImgs/B1.dot --pkg=Cairo
	Julia4 ../src/MetaRegInfo.jl --rev -i --dot dotImgs/B1rev.dot --pkg=Cairo
	Julia4 ../src/MetaRegInfo.jl   --dot dotImgs/C1.dot 
	Julia4 ../src/MetaRegInfo.jl   -i --dot dotImgs/C2.dot 
	Julia4 ../src/MetaRegInfo.jl  --rev --dot dotImgs/C1rev.dot  
	Julia4 ../src/MetaRegInfo.jl  --rev  -i --dot dotImgs/C2rev.dot 

testCmd2: dotImgs/A1.jpg dotImgs/A1rev.jpg dotImgs/B1.jpg dotImgs/B1rev.jpg \
          dotImgs/C1.jpg dotImgs/C1rev.jpg dotImgs/C2.jpg dotImgs/C2rev.jpg 

.PHONY: testCmd3 testCmd4  testCmd5 testCmd5b testCmd6
testCmd3:
	Julia4 ../src/MetaRegInfo.jl --dot dotImgs/P1.dot --pivot --pkg=Cairo
	Julia4 ../src/MetaRegInfo.jl -i --dot dotImgs/P2.dot --pivot --pkg=Cairo

testCmd4: dotImgs/P1.jpg dotImgs/P2.jpg

testCmd5:
	Julia4 ../src/MetaRegInfo.jl --dot dotImgs/MA.dot  --both
	Julia4 ../src/MetaRegInfo.jl --dot dotImgs/M1.dot --pivot --both --pkg=Cairo
	Julia4 ../src/MetaRegInfo.jl --dot dotImgs/M2.dot --both --pkg=Cairo
	Julia4 ../src/MetaRegInfo.jl --dot dotImgs/M3.dot --both --rev --pkg=Cairo


testCmd6: dotImgs/M1.jpg dotImgs/M2.jpg dotImgs/M3.jpg dotImgs/MA.jpg


testCmd: testCmd1 testCmd2 testCmd3 testCmd4

all : runtests jpgs pdfs testCmd

.PHONY:  runtests

runtests:
	Julia4 runtests.jl
	ddot dotImgs/T1merge.dot 
	tojpg dotImgs/T1merge.pdf 
	display dotImgs/T1merge.jpg 
	ddot dotImgs/T2merge.dot 
	tojpg dotImgs/T2merge.pdf 
	display dotImgs/T2merge.jpg 
	ddot dotImgs/T4merge.dot 
	tojpg dotImgs/T4merge.pdf 
	display dotImgs/T4merge.jpg

