#! /bin/bash
#
# script:	mitop.sh
# Autor:	MISRRAIM SUÁREZ PÉREZ
# mail:		misrraimsp@gmail.com
# revisión:	30/11/2016
#
# Presenta en pantalla información estadística de los procesos presentes en el sistema. Los procesos
# son ordenados decrecientemente según el porcentaje de uso de la CPU, mostrando únicamente los 'n'
# mayores. Por defecto 'n = 10', esto es, si el parámetro 'n' no es especificado se muestra los 10
# procesos con mayor uso de la CPU. Si el valor del parámetro es superior al número de procesos en
# el sistema se muestra información de todos los procesos.
#
# Usage: 'mitop n'
#
###############################################	CONFIGURACIÓN ###############################################
###############################################

# clock ticks per second
hrtz=$(getconf CLK_TCK)

# anchos de cada campo, respectivamente:
# PID, USER, PR, VIRT, S, %CPU, %MEM, TIME, CMD
ancho_campos=( 9 12 7 10 5 8 8 10 15 )

# anchos de la cabecera, respectivamente:
# texto, valor		
ancho_cabecera=( 20 10 )

# elemento con que construir las lineas delimitadoras
brick="-"

###############################################	FUNCIONES ###############################################
###############################################

# Función que permite obtener el nombre de usuario de un proceso dado, facilitando como parámetro el
# PID identificador del proceso.
#
# Usage: 'pid2uname PID'
#
pid2uname()
{
	if [ -n "$1" ]; then
		dirStatus="/proc/$1/status"
		if [ -e $dirStatus ]; then
			# obtengo el UID real del proceso
			UserID=$(cat $dirStatus | grep "^Uid:" | awk {'print $2'})
			# con el UID obtengo el nombre de usuario		
			cat "/etc/passwd" | grep "^[[:alnum:]]*:[[:alnum:]]*:$UserID:" | cut -d: -f1
		else
			# no existe el proceso
			echo "PID error: $1"
		fi
	else
		# falta especificar proceso
		echo "Usage: pid2uname PID"
	fi	
}

# Función que añade espacios al final, o recorta del final, de tal forma que el tamaño del primer
# parámetro (cadena) se ajuste al definido en el segundo parámetro (tamaño)
#
# Usage: 'format cadena tamaño'
#
format()
{
	salida="$1" 
	numChar=$(echo -n "$salida" | wc -m)
	let anchoColum=$2
	
	let disponible=anchoColum-numChar
	
	# si necesario añado espacios al final
	while [[ $disponible -gt 0 ]]; do
		salida="$salida "
		disponible=$(($disponible-1))
	done
	
	# si necesario trunco la cadena al final
	while [[ $disponible -lt 0 ]]; do
		salida=${salida%[[:alnum:]]}
		disponible=$(($disponible+1))
	done
			
	echo "$salida"
}

# Imprime una linea delimitadora teniendo el cuenta los anchos de los campos. La linea se construye
# con el parámetro pasado.
#
# Usage: 'getline par'
#
getline()
{
	atom="$1"
	salida=""
	for VALUE in ${ancho_campos[@]}; do
		let cont=0
		while [[ $cont -lt $VALUE ]]; do
			salida="$salida$atom"
			cont=$(( $cont + 1 ))
		done
	done
	echo -n "$salida"
}

###############################################	LECTURAS ###############################################
###############################################

# Obtengo los nombres de los procesos, ordenados
procesos=$(ls "/proc" | grep "[[:digit:]]" | sort -n)

# Leo stat del sistema INICIAL
SyStat_i=$(cat "/proc/stat")

# Leo stat de cada proceso. Guardo en PrStat_i que es un vector con los contenidos INICIALES
# de los ficheros /proc/[PID]/stat. El elemento para indexar el vector es el PID del proceso.
for VALUE in $procesos; do
	dir="/proc/$VALUE/stat"
	if [ -e "$dir" ]; then
		PrStat_i[$VALUE]=$(cat $dir)
	fi
done

# Siesta
sleep 1

# Leo stat del sistema FINAL
SyStat_f=$(cat "/proc/stat")

# Leo stat de cada proceso. Guardo en PrStat_f que es un vector con los contenidos FINALES
# de los ficheros /proc/[PID]/stat. El elemento para indexar el vector es el PID del proceso.
for VALUE in $procesos; do
	dir="/proc/$VALUE/stat"
	if [ -e "$dir" ]; then
		PrStat_f[$VALUE]=$(cat $dir)
	fi
done

###############################################	USO TOTAL CPU ###############################################
###############################################

# Extraigo los tiempos iniciales de SyStat_i
aux=( $(echo $SyStat_i | cut -d" " -f 2-11) )
user_i=${aux[0]}
nice_i=${aux[1]}
system_i=${aux[2]}
idle_i=${aux[3]}
iowait_i=${aux[4]}
irq_i=${aux[5]}
softirq_i=${aux[6]}
steal_i=${aux[7]}
# Extraigo los tiempos finales de SyStat_f
aux=( $(echo $SyStat_f | cut -d" " -f 2-11) )
user_f=${aux[0]}
nice_f=${aux[1]}
system_f=${aux[2]}
idle_f=${aux[3]}
iowait_f=${aux[4]}
irq_f=${aux[5]}
softirq_f=${aux[6]}
steal_f=${aux[7]}

# ticks total
let total_i=$((user_i + nice_i + system_i + idle_i + iowait_i + irq_i + softirq_i + steal_i))
let total_f=$((user_f + nice_f + system_f + idle_f + iowait_f + irq_f + softirq_f + steal_f))
let total_diff=$((total_f - total_i))

# ticks idle
let idle_i=$((idle_i + iowait_i))
let idle_f=$((idle_f + iowait_f))
let idle_diff=$((idle_f - idle_i))

# CPU% Usage
syscpu=$( echo "scale=2; 100 * (1 - $idle_diff / $total_diff)" | bc )

###############################################	USO TOTAL MEMORIA ###############################################
###############################################

# vector con la memoria total y libre
memInfo=( $(cat "/proc/meminfo" | awk {'print $2'} | cut -d" " -f 1,2) )

# unidad de medida de la memoria
memUnit=$(cat "/proc/meminfo" | awk {'print $3'} | head -1)

# memoria total
memTotal=${memInfo[0]}

# memoria libre
memFree=${memInfo[1]}

# memoria ocupada
memBusy=$((memTotal - memFree))

###############################################	GESTIÓN PROCESOS ###############################################
###############################################
#
# PASO 1: Primero filtro los procesos de mayor uso CPU. Para ello obtengo los campos
# 14 y 15 de /proc/[PID]/stat de todos los procesos.
#

todos=""
numPr=0 # numero de procesos coincidentes en las dos lecturas
for VALUE in $procesos; do
	if [ -n "${PrStat_i[$VALUE]}" ] && [ -n "${PrStat_f[$VALUE]}" ]; then
		numPr=$((numPr + 1)) # contabilizo el proceso
		tui=$(echo ${PrStat_i[$VALUE]} | awk {'print $14'})
		tuf=$(echo ${PrStat_f[$VALUE]} | awk {'print $14'})
		tsi=$(echo ${PrStat_i[$VALUE]} | awk {'print $15'})
		tsf=$(echo ${PrStat_f[$VALUE]} | awk {'print $15'})
		inc=$(( (tuf - tui) + (tsf - tsi) ))
		todos="$todos$inc\t$VALUE\n"
	fi
done
filtrados=$(echo -e "$todos" | sort -nr | head -${1:-10}) # filtro, por defecto, los 10 mayores

#
# PASO 2: Una vez obtenidos los procesos deseados se obtiene el resto de información, presentada
# como concatenación de los diferentes campos en una única variable llamada 'salida'. En la
# concatenación de los campos se llama primero a la función 'format' para garantizar la homogeneidad
# de tamaños. Ver función 'format cadena tamaño'.
#

salida=""
# Recorro los PID filtrados. Cada iteración da forma a una linea con la info de un proceso.
for VALUE in $(echo -e "$filtrados" | awk {'print $2'}); do
	
	# attach PID. Inicio la linea con el PID del proceso
	salida="$salida$(format $VALUE ${ancho_campos[0]})"
	
	# attach NAME
	NAME=$(pid2uname $VALUE)
	salida="$salida$(format $NAME ${ancho_campos[1]})"

	# attach PRIORITY
	PR=$(echo ${PrStat_i[$VALUE]} | awk {'print $18'})
	salida="$salida$(format $PR ${ancho_campos[2]})"
	
	# attach VIRTUAL MEMORY
	VM_bytes=$(echo ${PrStat_i[$VALUE]} | awk {'print $23'})
	VM=$( echo "	$VM_bytes / 1024" | bc )
	salida="$salida$(format $VM ${ancho_campos[3]})"
	
	# attach STATE
	S=$(echo ${PrStat_i[$VALUE]} | awk {'print $3'})
	salida="$salida$(format $S ${ancho_campos[4]})"
	
	# attach CPU%
	inc=$(echo "$filtrados" | grep -x "[[:digit:]]*[[:space:]]$VALUE" | awk {'print $1'})
	CPU=$( echo "scale=2; 100 * $inc / $total_diff" | bc )
	salida="$salida$(format $CPU ${ancho_campos[5]})"
	
	# attach MEM%
	MEM=$( echo "scale=2; 100 * $VM / $memTotal" | bc )
	salida="$salida$(format $MEM ${ancho_campos[6]})"
	
	# attach TIME
	boottime=$(cat "/proc/uptime" | awk {'print $1'})
	starttime_ticks=$(echo ${PrStat_i[$VALUE]} | awk {'print $22'})
	TIME=$( echo "$boottime - ($starttime_ticks / $hrtz)" | bc )
	salida="$salida$(format ${TIME%.*} ${ancho_campos[7]})" #elimino los decimales del tiempo
	
	# attach COMMAND
	CMD=$(echo ${PrStat_i[$VALUE]} | awk {'print $2'})
	CMD=${CMD%")"}
	CMD=${CMD#"("}
	salida="$salida$(format $CMD ${ancho_campos[8]})\n"
	
done

###############################################	IMPRESIÓN ###############################################
###############################################

line=$(getline $brick)

# Cabecera
echo "$line"

echo -n "$( format "Nro de Procesos:" ${ancho_cabecera[0]} )"
echo "$( format "$numPr" ${ancho_cabecera[1]} )"

echo -n "$( format "CPU% Usage:" ${ancho_cabecera[0]} )"
echo "$( format "$syscpu" ${ancho_cabecera[1]} )"

echo -n "$( format "Memoria Total:" ${ancho_cabecera[0]} )"
echo "$( format "$memTotal" ${ancho_cabecera[1]} )$memUnit"

echo -n "$( format "Memoria Utilizada:" ${ancho_cabecera[0]} )"
echo "$( format "$memBusy" ${ancho_cabecera[1]} )$memUnit"

echo -n "$( format "Memoria Libre:" ${ancho_cabecera[0]} )"
echo "$( format "$memFree" ${ancho_cabecera[1]} )$memUnit"

# Leyenda
echo "$line"

echo -n "$(format "PID" ${ancho_campos[0]})"
echo -n "$(format "USER" ${ancho_campos[1]})"
echo -n "$(format "PR" ${ancho_campos[2]})"
echo -n "$(format "VIRT" ${ancho_campos[3]})"
echo -n "$(format "S" ${ancho_campos[4]})"
echo -n "$(format "%CPU" ${ancho_campos[5]})"
echo -n "$(format "%MEM" ${ancho_campos[6]})"
echo -n "$(format "TIME" ${ancho_campos[7]})"
echo "$(format "CMD" ${ancho_campos[8]})"

# Datos Procesos
echo "$line"

echo -ne "$salida"

echo "$line"