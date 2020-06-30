#!/bin/bash

DATE=$(date +"%Y_%m_%d_%I_%M")
SSOCR=$(which ssocr)
OUTPUT_FILENAME="/opt/pi/temps"
# CROP_COORDS="75 125 382 170"
TOP="135"
LEFT="6"
WIDTH="396"
HEIGHT="202"
RIGHT="$((LEFT+WIDTH))"
BOTTOM="$((TOP+HEIGHT))"
CROP_COORDS="${LEFT} ${TOP} ${WIDTH} ${HEIGHT}"
DRAW_COORDS="${LEFT},${TOP} ${RIGHT},${BOTTOM}"
BATCH_NAME="bv_1"
MAX_ACCEPTED_TEMP="29"
MIN_ACCEPTED_TEMP="16"

set -x
while true; do
	# Take photo using current date	
	DATE=$(date +"%Y-%m-%d-%H%M")
        FILENAME="${DATE}.png"
	IMAGE_OUTPUT_DIR="/opt/pi/images"
	fswebcam --fps 15 -S 8 -r 640x480 --no-banner ${FILENAME}

	ARRAY=()
	X=0

	# Try different thresholds
	for I in 90 80 70 60 50 40 30 20 10; do

		# Ensure there is at least PIX pixels
		for PIX in 50 20 5; do
			
			# Shear image by different amounts 
			#for SHEAR in 0 1 4 7 10; do

				Z=$(${SSOCR} -d3 -i$PIX crop ${CROP_COORDS} shear $SHEAR -t$I -b black -f white ${FILENAME} -o dump.png)

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
			#done
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

		if (( $(echo "$NUM > $MAX_ACCEPTED_TEMP" | bc -l) )); then
			echo ${DATE} >> bad
			convert "${FILENAME}" -fill none -stroke red -draw "rectangle ${DRAW_COORDS}" "${IMAGE_OUTPUT_DIR}/last-bad.png"
		elif (( $(echo "$NUM < $MIN_ACCEPTED_TEMP" | bc -l) )); then
			echo ${DATE} >> bad
			convert "${FILENAME}" -fill none -stroke red -draw "rectangle ${DRAW_COORDS}" "${IMAGE_OUTPUT_DIR}/last-bad.png"
		else
			# Write number to CSV
			echo "temperature,brew=${BATCH_NAME} temperature=${NUM}" >> ${OUTPUT_FILENAME}
			convert "${FILENAME}" -fill none -stroke green -draw "rectangle ${DRAW_COORDS}" "${IMAGE_OUTPUT_DIR}/last-good.png"
		fi
		
		rm ${FILENAME}
	fi

	sleep 60
done
