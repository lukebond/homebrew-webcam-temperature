#!/bin/bash

SSOCR="/home/luke/Development/ssocr/ssocr"
FILENAME="${DATE}.png"
OUTPUT_FILENAME="/opt/temps"
while true; do

	# Take photo using current date	
	DATE=$(date +"%Y-%m-%d-%H%M")
	# raspistill -vf -hf -o $DATE.jpg
	cp /home/luke/Development/go/src/github.com/blackjack/webcam/ssocr-temp/output-golang ${FILENAME}

	ARRAY=()
	X=0

	# Try different thresholds
	for I in 90 80 70 60 50 40 30 20 10; do

		# Ensure there is at least PIX pixels
		for PIX in 50 20 5; do
			
			# Shear image by different amounts 
			for SHEAR in 0 1 4 7 10; do

				Z=$(${SSOCR} -d3 -i$PIX crop 30 95 460 220 shear $SHEAR -t$I -b black -f white ${FILENAME} -o dump.png)

        # original script converted b to 6 because i guess it was an issue
				# Z=$(echo $Z | sed "s/b/6/g;s/\.//g")

				# Ensure exit code was 0, meaning OCR detected numbers of 3 digits
				if [ $? -eq 0 ] && [[ ${Z} =~ ^[0-9]+$ ]] && [ ${#Z} -ge 2 ] && [ ${#Z} -le 3 ]; then
				
					echo $Z
				
					# Store number from OCR as integer, convert b to 6 
					# (as ssocr sometimes thinks 6 is B in hex)

					NUMI=$(echo "$(echo $Z)" | bc)

					((ARRAY[$NUMI]++))
					X=1
				fi
			done
		done 
	done

	if [ $X -eq 0 ]; then
		# Failed to detect display correctly	
		echo ${DATE} >> bad
	else
		LOW=0
		LVAL=-1

		# Find best value out of possible candidate OCRd values
		for var in "${!ARRAY[@]}";
		do	
			# Check if this number appears the most common	
			if [ ${ARRAY[$var]} -gt $LOW ]; then
				LOW=${ARRAY[$var]}
				LVAL=$var
			fi
		done
		
		# Convert number to decimal
		NUM=$(echo "scale = 2; $LVAL / 10" | bc)

		# Write number to CSV
		echo "temperature,brew=haze_v5 temperature=${NUM}" >> ${OUTPUT_FILENAME}
		
		rm ${FILENAME}
	fi

	sleep 60
done
