#!/system/bin/sh
#
# 20120107 - SENSEISIMPLE
#
log -p i -t init:firstboot "INIT.firstboot BEGIN: USER SCRIPT $FBLOC.sh"
sleeperlog "FirstBoot Script OK TO RUN"

FBLOC="/data/.firstboot"
tmp="/cache/tmp/firstboot"
bak="$tmp/bak/data/data/"

BB="busybox"
RM="$BB rm"
CP="$BB cp"
MV="$BB mv"
MKDIR="$BB mkdir"
LS="$BB ls"
CHMOD="$BB chmod"
SLEEP="$BB sleep"
GREP="$BB grep"



pg () {
	$BB ps | $BB grep "$@" | $BB grep -v "$( echo $BB grep $@ )"
}

$CHMOD 0777 /data

#install apps on first boot
if [ -d $FBLOC ]; then
	sleeperlog "Found $FBLOC"

	if [ "$($LS $FBLOC)" ]; then
		cd $FBLOC
		$MKDIR -p $bak
		for pkg in *.apk; do
			log -p i -t init:firstboot "INIT.firstboot INSTALLING: $pkg"
			sleeperlog "PREPARING: $pkg"

			pkgname=${pkg%.*}
			sleeperlog "BACKING UP APP DATA - $pkgname"
			#back up data, delete the original data dir to prevent install errors (pm isn't very good at what it does)
			if [ -d /data/data/$pkgname ]; then
				$CP -a /data/data/$pkgname $bak/$pkgname
				$RM -rf /data/data/$pkgname
			fi

			#WAIT, then install, then WAIT SOME MORE
			$SLEEP 2
			sleeperlog "INSTALLING $pkgname"
			pm install -r $FBLOC/$pkg &
			$SLEEP 10

			#REIntegrate application data
			if [ -d "$bak/$pkgname" ]; then
				 sleeperlog "\nSYNCING APP DATA \n\n$(/system/xbin/rsync -auv --exclude=lib $bak/$pkgname/ /data/data/$pkgname/)\n"
			fi
			i=$((i+1))

			#Move the install .apk to tmp
			if $LS /data/app | $GREP "$pkgname"; then
				sleeperlog "Package appears to have installed."
				$MV "$pkg" $tmp/
			fi
			#If the firstboot batch dir is empty, delete it now
			! [ "$($LS $FBLOC)" ] && $RM -rf $FBLOC
		done

		#WAIT for [#ofapps x 5 seconds each] to avoid a race condition
		waitsecs=$(( i * 5 ))
		sleeperlog "Waiting for ${waitsecs}s before Fixing Permissions"
		$SLEEP $waitsecs
		sleeperlog "Fixing Permissions $(/system/xbin/fix_permissions)"
		sleeperlog "Running batch zipalign \n\n $(/system/xbin/zipalign)"
		sleeperlog "Clearing tmp $tmp"

	fi

fi

sleeperlog "FIRSTBOOT SCRIPT COMPLETE"

log -p i -t init:firstboot "INIT.firstboot SELF DESTRUCT FIRSTBOOTSCRIPT"
if ! [ "$($LS $FBLOC)" ]; then
	$MV $0 $tmp/.firstboot
	# COMMENT THIS OUT FOR DEBUGGING, TO NOT REMOVE THE TMP DIR
	$RM -r $tmp
	echo ""
fi
echo -e "#\n#COMPLETED ON $(date)\n#" >> $0
sleeperlog "FirstBoot Apoptosis"
log -p i -t init:firstboot "INIT.firstboot END: USER SCRIPT $FBLOC.sh"