#!/bin/bash

function FolderAbsolutePath()
{
	(
		cd "$1"
		pwd
	)
}

DateTimeToken=$( date +%Y%m%d-%H%M%S )
RndToken=${DateTimeToken}-${RANDOM}
