<?
/*
-----------------------------------------------------------------------------------------------------------------------------------------
Command 1 - Systemfunktionen

Achtung: Diese Queue-Befehle können auch angefordert werden, während EDOMI noch auf Start/Projektaktivierung wartet!

$argv[1]=db.RAMcmdQueue.id
$argv[2]=(Platzhalter)
$argv[3]=db.RAMcmdQueue.cmd
$argv[4]=db.RAMcmdQueue.cmdid
$argv[5]=db.RAMcmdQueue.cmdvalue
-----------------------------------------------------------------------------------------------------------------------------------------
*/

//Globale Includes
require(dirname(__FILE__)."/../../www/shared/php/config.php");
require(MAIN_PATH."/www/shared/php/base.php");
require(MAIN_PATH."/www/shared/php/incl_dbinit.php");

require(MAIN_PATH."/www/admin/include/php/base.php");	//nur für Updates (LBS-Import)

//Eigene Includes
require(MAIN_PATH."/main/include/php/config.php");
require(MAIN_PATH."/main/include/php/base.php");
require(MAIN_PATH."/main/include/php/update.php");
require(MAIN_PATH."/main/include/php/incl_cmd.php");
require(MAIN_PATH."/main/include/php/incl_log.php");
require(MAIN_PATH."/main/include/php/incl_ga.php");
require(MAIN_PATH."/main/include/php/incl_telnet.php");
require(MAIN_PATH."/main/include/php/incl_fritzbox.php");


sql_connect();

if ($argv[4]==1) {backup(1,$argv[5]);}
if ($argv[4]==2) {backup(2,'');}
if ($argv[4]==3) {dbAndLogRotate();}
if ($argv[4]==4) {saveServerIp();}
if ($argv[4]==5) {saveProject($argv[5]);}
if ($argv[4]==6) {loadProject($argv[5]);}
if ($argv[4]==7) {restore($argv[5]);}
if ($argv[4]==8) {callServerHeartbeatURL();}
if ($argv[4]==9) {systemupdate($argv[5]);}
if ($argv[4]==10) {autoupdate($argv[5]);}
sql_call("DELETE FROM edomiLive.RAMcmdQueue WHERE (id=".$argv[1]." AND status=1)");


sql_disconnect();

//--------------------------

function backup($mode,$fn) {
	//$mode: 1=Download-Backup, 2=Autobackup (Server/Visu)
	//$fn: nur bei $mode=1: Dateiname der Backupdatei (ohne Pfad)

	//Backup-Verzeichnis ggf. anlegen
	exec('mkdir '.BACKUP_PATH);

	if ($mode==1) {
		//Download-Backup
		writeToLog(0,true,'Download-Backup erstellen: '.$fn);

		//alte Datei löschen
		deleteFiles(BACKUP_PATH.'/'.$fn);
		deleteFiles(MAIN_PATH.'/www/data/tmp/'.$fn);

		//Backup erstellen
		exec('tar -cf '.BACKUP_PATH.'/'.$fn.' '.MAIN_PATH.'/ --exclude='.MAIN_PATH.'/www/data/tmp/*');
		sql_call("FLUSH TABLES ".sql_getAllTables(false)." WITH READ LOCK");
		exec('tar -rf '.BACKUP_PATH.'/'.$fn.' '.MYSQL_PATH.'/edomiProject');
		exec('tar -rf '.BACKUP_PATH.'/'.$fn.' '.MYSQL_PATH.'/edomiAdmin');
		exec('tar -rf '.BACKUP_PATH.'/'.$fn.' '.MYSQL_PATH.'/edomiLive --exclude='.MYSQL_PATH.'/edomiLive/RAM*.*');
		sql_call("UNLOCK TABLES");

		//ins Projekt-Tmp-Verzeichnis kopieren (für Download-Rechte)
		exec('cp '.BACKUP_PATH.'/'.$fn.' '.MAIN_PATH.'/www/data/tmp');

		//Adminseite mitteilen, dass das Backup erstellt wurde
		createInfoFile(MAIN_PATH.'/www/data/tmp/backupready.txt',array('ok'));

	} else if ($mode==2) { 
		//Autobackup (Server/Visu)
		$fn=date('Y-m-d-His').'.edomibackup';
		writeToLog(0,true,'Autobackup erstellen: '.$fn);

		//Backup erstellen
		exec('tar -cf '.BACKUP_PATH.'/'.$fn.' '.MAIN_PATH.'/ --exclude='.MAIN_PATH.'/www/data/tmp/*');
		sql_call("FLUSH TABLES ".sql_getAllTables(false)." WITH READ LOCK");
		exec('tar -rf '.BACKUP_PATH.'/'.$fn.' '.MYSQL_PATH.'/edomiProject');
		exec('tar -rf '.BACKUP_PATH.'/'.$fn.' '.MYSQL_PATH.'/edomiAdmin');
		exec('tar -rf '.BACKUP_PATH.'/'.$fn.' '.MYSQL_PATH.'/edomiLive --exclude='.MYSQL_PATH.'/edomiLive/RAM*.*');
		sql_call("UNLOCK TABLES");
	}
}

function restore($fn) {
	//stellt die Backupdatei BACKUP_PATH/$fn wieder her
	//$fn: Dateiname ohne Pfad (muss im Verzeichnis BACKUP_PATH liegen)

	if (file_exists(BACKUP_PATH.'/'.$fn)) {
		writeToLog(0,true,'Restore einspielen: '.$fn);

		//nach /tmp (System!) kopieren und in edomirestore.data umbennen
		exec('cp "'.BACKUP_PATH.'/'.$fn.'" /tmp/edomirestore.data');

		//Script-Datei /tmp/edomirestore.sh erstellen
		$fh=fopen('/tmp/edomirestore.sh','w');
			//warten, bis start.sh garantiert beendet ist
			fwrite($fh,'echo ""'."\n");
			fwrite($fh,'echo "--------------------------------------------------------------------------------"'."\n");
			fwrite($fh,'echo "edomirestore.sh"'."\n");
			fwrite($fh,'echo "Restore wird gestartet"'."\n");
			fwrite($fh,'echo "--------------------------------------------------------------------------------"'."\n");
			fwrite($fh,'sleep 3s'."\n");
			fwrite($fh,'clear'."\n");
	
			//mySQL und HTTPd stoppen
			fwrite($fh,'service mysqld stop'."\n");
			fwrite($fh,'service httpd stop'."\n");
			fwrite($fh,'sleep 1s'."\n");

			//EDOMI/mySQL komplett löschen
			fwrite($fh,'rm -rf '.MAIN_PATH."\n");
			fwrite($fh,'rm -f '.MYSQL_PATH.'/mysql.sock'."\n");
			fwrite($fh,'rm -rf '.MYSQL_PATH.'/edomiAdmin'."\n");
			fwrite($fh,'rm -rf '.MYSQL_PATH.'/edomiProject'."\n");
			fwrite($fh,'rm -rf '.MYSQL_PATH.'/edomiLive'."\n");
			fwrite($fh,'sleep 1s'."\n");
	
			//Einspielen
			fwrite($fh,'tar -xf /tmp/edomirestore.data -C /'."\n");
			fwrite($fh,'chmod 777 -R '.MAIN_PATH."\n");
	
			//Aufräumen
			fwrite($fh,'rm -f /tmp/edomirestore.data'."\n");	
	
			//mySQL und HTTPd starten
			fwrite($fh,'service mysqld start'."\n");
			fwrite($fh,'service httpd start'."\n");
			
			//mySQL-Datenbanken ggf. reparieren (ist etwas riskant, da Fehler die DB zerstören können)
			//fwrite($fh,'mysqlcheck -A --auto-repair'."\n");
	
			//Reboot
			fwrite($fh,'echo "--------------------------------------------------------------------------------"'."\n");
			fwrite($fh,'echo "Restore abgeschlossen. Reboot in 5 Sekunden..."'."\n");
			fwrite($fh,'echo "--------------------------------------------------------------------------------"'."\n");
			fwrite($fh,'sleep 5s'."\n");
			fwrite($fh,'reboot'."\n");
			fwrite($fh,'exit'."\n");
		fclose($fh);
		
		//Adminseite mitteilen, dass das Restore vorbereitet wurde
		createInfoFile(MAIN_PATH.'/www/data/tmp/restoreready.txt',array('ok'));
	}
}

function systemupdate($fn) {
	//$fn: Dateiname ohne Pfad (muss im Verzeichnis data/tmp liegen)

	if (file_exists(MAIN_PATH.'/www/data/tmp/'.$fn)) {

		//Filename parsen: Versionskontrolle
		//	Filename muss diesem Schema folgen: *_XYY.*
		//	Bedeutung: 
		//		XYY=Version des Updates, z.B. 143 (=1.43)
		//		Update-Version muss stets 0.01 größer sein als die aktuelle Version!
		if (preg_match('/\_(.*?)\./s',$fn,$v)>0) {
			$vUpdate=(($v[1]/100)-0.01);
			if ((string)global_version==(string)$vUpdate) {							
							
				writeToLog(0,true,'EDOMI-Update installieren: '.$fn);
				
				//nach /tmp (System!) verschieben und in edomiupdate.data umbennen
				exec('mv "'.MAIN_PATH.'/www/data/tmp/'.$fn.'" /tmp/edomiupdate.data');
		
				//Script-Datei /tmp/edomiupdate.sh erstellen
				$fh=fopen('/tmp/edomiupdate.sh','w');
					//warten, bis start.sh garantiert beendet ist
					fwrite($fh,'echo ""'."\n");
					fwrite($fh,'echo "--------------------------------------------------------------------------------"'."\n");
					fwrite($fh,'echo "edomiupdate.sh"'."\n");
					fwrite($fh,'echo "Update wird installiert"'."\n");
					fwrite($fh,'echo "--------------------------------------------------------------------------------"'."\n");
					fwrite($fh,'sleep 3s'."\n");
					fwrite($fh,'clear'."\n");
		
					//HTTPd stoppen
					fwrite($fh,'service httpd stop'."\n");
					fwrite($fh,'sleep 1s'."\n");
		
					//Einspielen 
					fwrite($fh,'tar -xf /tmp/edomiupdate.data -C '.MAIN_PATH.' --strip-components=3'."\n");
					fwrite($fh,'chmod 777 -R '.MAIN_PATH."\n");
			
					//Aufräumen
					fwrite($fh,'rm -f /tmp/edomiupdate.data'."\n");	
			
					//HTTPd starten
					fwrite($fh,'service httpd start'."\n");
					fwrite($fh,'sleep 1s'."\n");
		
					//Update-Script ggf. ausführen und danach löschen
					fwrite($fh,'if [ -f '.MAIN_PATH.'/main/_edomiupdate.php ]; then'."\n");
					fwrite($fh,'php '.MAIN_PATH.'/main/_edomiupdate.php'."\n");
					fwrite($fh,'rm -f '.MAIN_PATH.'/main/_edomiupdate.php'."\n");
					fwrite($fh,'fi'."\n");
		
					//Reboot
					fwrite($fh,'echo "--------------------------------------------------------------------------------"'."\n");
					fwrite($fh,'echo "Update abgeschlossen. Reboot in 5 Sekunden..."'."\n");
					fwrite($fh,'echo "--------------------------------------------------------------------------------"'."\n");
					fwrite($fh,'sleep 5s'."\n");
					fwrite($fh,'reboot'."\n");
					fwrite($fh,'exit'."\n");
				fclose($fh);
				
				//Adminseite mitteilen, dass das Update vorbereitet wurde
				createInfoFile(MAIN_PATH.'/www/data/tmp/updateready.txt',array('ok'));
				
			} else {
				
				//Update passt nicht zur Version
				deleteFiles(MAIN_PATH.'/www/data/tmp/'.$fn);
				writeToLog(0,false,'EDOMI-Update installieren ('.$fn.') gescheitert: Falsche Version!');
				return false;
				
			}
		}
	}
}

function autoupdate($download) {
	//$download: 0=nur prüfen und ggf. SysKO setzen, 1=prüfen und Download, 2=wie 0 jedoch ohne Infodatei-Erstellung (MAIN)

	if (!isEmpty(global_urlAutoupdate)) {
		$clientId=get_clientId();
		$clientId_encrypt=strToUpper(hash('sha256',$clientId));
		$url=global_urlAutoupdate.'/checkupdate.php?clientid='.$clientId.'&version='.global_version.'&'.date('YmdHis');

		if ($download==2) {writeToLog(0,true,'EDOMI-Autoupdate: Update-Verfügbarkeit prüfen');}

		$ctx=stream_context_create(array('http' => array('timeout'=>10)));	//10 Sekunden Timeout
		$r=file_get_contents($url,false,$ctx);

		$response=explode('/',$r);
		if (count($response)==6 && $response[0]='OK' && $response[1]==$clientId_encrypt && is_numeric($response[2]) && !isEmpty($response[5])) {
			//Update verfügbar und Berechtigung vorhanden
			
			//SysKO(12) setzen
			$n=getGADataFromID(12,2,'value');
			if ($n['value']!=1) {writeGA(12,1);}
			
			if ($download==1) {
				//Download
				$url=global_urlAutoupdate.'/'.$response[4].'?'.date('YmdHis');
				$tmpFn='TMP_'.$response[4];
				deleteFiles(MAIN_PATH.'/www/data/tmp/'.$tmpFn);
				if (urlDownload($url,$tmpFn,'autoupdatedownload.txt',$response[3])) {
					if (getFileSize(MAIN_PATH.'/www/data/tmp/'.$tmpFn)==$response[3] && getFileMd5(MAIN_PATH.'/www/data/tmp/'.$tmpFn)==$response[5]) {
						//Download erfolgreich
						rename(MAIN_PATH.'/www/data/tmp/'.$tmpFn,MAIN_PATH.'/www/data/tmp/'.$response[4]);
						writeToLog(0,true,'EDOMI-Autoupdate: Download von Update-Version '.$response[2].' erfolgreich');
						createInfoFile(MAIN_PATH.'/www/data/tmp/autoupdateinfo.txt',array('DOWNLOADED',$response[2],$response[3],$response[4]));	//Adminseite informieren
					} else {
						//Dateiprüfung nach Download fehlgeschlagen		
						deleteFiles(MAIN_PATH.'/www/data/tmp/'.$tmpFn);
						writeToLog(0,false,'EDOMI-Autoupdate: Ungültige Prüfsumme');
						createInfoFile(MAIN_PATH.'/www/data/tmp/autoupdateinfo.txt',array('ERROR',$response[2],$response[3]));	//Adminseite informieren
					}
				} else {
					//Download fehlgeschlagen
					deleteFiles(MAIN_PATH.'/www/data/tmp/'.$tmpFn);
					writeToLog(0,false,'EDOMI-Autoupdate: Download gescheitert');
					createInfoFile(MAIN_PATH.'/www/data/tmp/autoupdateinfo.txt',array('ERROR',$response[2],$response[3]));	//Adminseite informieren
				}
				
			} else {
				//Update verfügbar (nur Check, kein Download)
				if ($download==0) {createInfoFile(MAIN_PATH.'/www/data/tmp/autoupdateinfo.txt',array('CHECKED',$response[2],$response[3]));}	//Adminseite informieren
			}

		} else {
			//kein Update verfügbar oder Fehler (z.B. keine Verbindung zum Update-Server)
			if ($r=='NOUPDATE') {
				if ($download==0) {createInfoFile(MAIN_PATH.'/www/data/tmp/autoupdateinfo.txt',array('NOUPDATE'));}
			} else {
				if ($download==0) {createInfoFile(MAIN_PATH.'/www/data/tmp/autoupdateinfo.txt',array('ERROR'));}
			}
		}
		
	} else {
		//Autoupdate ist deaktiviert
		if ($download==0) {createInfoFile(MAIN_PATH.'/www/data/tmp/autoupdateinfo.txt',array('DISABLED'));}	//Adminseite informieren
	}
}

function dbAndLogRotate() {
	writeToLog(0,true,'Logs/Archive/Autobackups aufräumen');

	//Log-Dateien
	$keep=global_logSysKeep-1; if ($keep<1) {$keep=0;}
	exec("find ".MAIN_PATH."/www/data/log -mindepth 1 -maxdepth 1 -type f \( -name 'SYSLOG_*.*' \) -ctime +".$keep." -delete");

	$keep=global_logErrKeep-1; if ($keep<1) {$keep=0;}
	exec("find ".MAIN_PATH."/www/data/log -mindepth 1 -maxdepth 1 -type f \( -name 'ERRLOG_*.*' \) -ctime +".$keep." -delete");

	$keep=global_logMonKeep-1; if ($keep<1) {$keep=0;}
	exec("find ".MAIN_PATH."/www/data/log -mindepth 1 -maxdepth 1 -type f \( -name 'MONLOG_*.*' \) -ctime +".$keep." -delete");

	$keep=global_logCustomKeep-1; if ($keep<1) {$keep=0;}
	exec("find ".MAIN_PATH."/www/data/log -mindepth 1 -maxdepth 1 -type f \( -name 'CUSTOMLOG_*.*' \) -ctime +".$keep." -delete");

	//Autobackups (und manuelles Backup)
	$keep=global_backupKeep-1; if ($keep<1) {$keep=0;}
	exec("find ".BACKUP_PATH." -mindepth 1 -maxdepth 1 -type f \( -name '*.edomibackup' \) -ctime +".$keep." -delete");

	//Datenarchiv
	$ss1=sql_call("SELECT * FROM edomiLive.archivKo WHERE (keep>0)");
	while ($n=sql_result($ss1)) {
		sql_call("DELETE FROM edomiLive.archivKoData WHERE (targetid=".$n['id']." AND DATE_ADD(datetime,INTERVAL ".$n['keep']." DAY)<=".sql_getNow().")");
		//Status-KO ggf. setzen
		if (sql_affectedRows()>0 && $n['outgaid']>0) {
			writeGA($n['outgaid'],sql_getCount('edomiLive.archivKoData','targetid='.$n['id']));
		}
	}
	sql_close($ss1);
	sql_call("OPTIMIZE TABLE edomiLive.archivKoData");

	//Meldungsarchiv
	$ss1=sql_call("SELECT * FROM edomiLive.archivMsg WHERE (keep>0)");
	while ($n=sql_result($ss1)) {
		sql_call("DELETE FROM edomiLive.archivMsgData WHERE (targetid=".$n['id']." AND DATE_ADD(datetime,INTERVAL ".$n['keep']." DAY)<=".sql_getNow().")");
		//Status-KO ggf. setzen
		if (sql_affectedRows()>0 && $n['outgaid']>0) {
			writeGA($n['outgaid'],sql_getCount('edomiLive.archivMsgData','targetid='.$n['id']));
		}
	}
	sql_close($ss1);
	sql_call("OPTIMIZE TABLE edomiLive.archivMsgData");

	//Anrufarchiv
	$ss1=sql_call("SELECT * FROM edomiLive.archivPhone WHERE (keep>0)");
	while ($n=sql_result($ss1)) {
		sql_call("DELETE FROM edomiLive.archivPhoneData WHERE (targetid=".$n['id']." AND DATE_ADD(datetime,INTERVAL ".$n['keep']." DAY)<=".sql_getNow().")");
		//Status-KO ggf. setzen
		if (sql_affectedRows()>0 && $n['outgaid']>0) {
			writeGA($n['outgaid'],sql_getCount('edomiLive.archivPhoneData','targetid='.$n['id']));
		}
	}
	sql_close($ss1);
	sql_call("OPTIMIZE TABLE edomiLive.archivPhoneData");

	//Cam-Archiv
	$ss1=sql_call("SELECT * FROM edomiLive.archivCam WHERE (keep>0)");
	while ($n=sql_result($ss1)) {
		$ss2=sql_call("SELECT * FROM edomiLive.archivCamData WHERE (targetid=".$n['id']." AND DATE_ADD(datetime,INTERVAL ".$n['keep']." DAY)<=".sql_getNow().")");
		while ($nn=sql_result($ss2)) {
			$fn=getArchivCamFilename($nn['targetid'],$nn['camid'],$nn['datetime'],$nn['ms']);			
			deleteFiles(MAIN_PATH.'/www/data/liveproject/cam/archiv/'.$fn.'.jpg');
		}
		sql_close($ss2);
		sql_call("DELETE FROM edomiLive.archivCamData WHERE (targetid=".$n['id']." AND DATE_ADD(datetime,INTERVAL ".$n['keep']." DAY)<=".sql_getNow().")");
		//Status-KO ggf. setzen
		if (sql_affectedRows()>0 && $n['outgaid']>0) {
			writeGA($n['outgaid'],sql_getCount('edomiLive.archivCamData','targetid='.$n['id']));
		}
	}
	sql_close($ss1);
	//Dateileichen löschen (Bilddateien ohne korrespondienden DB-Record)
	$files=glob(MAIN_PATH.'/www/data/liveproject/cam/archiv/*.jpg');
	foreach ($files as $pathFn) {
		if (is_file($pathFn)) {
			$n=explode('-',basename($pathFn));
			$nn[0]=substr($n[0],6,100);
			$nn[1]=substr($n[1],3,100);
			$nn[2]=date('Y-m-d',strtotime(substr($n[2],0,8)));
			$nn[3]=date('H:i:s',strtotime(substr($n[2],8,6)));
			$nn[4]=substr($n[2],14,6);
			$ss1=sql_call("SELECT targetid FROM edomiLive.archivCamData WHERE (targetid='".$nn[0]."' AND camid='".$nn[1]."' AND datetime='".date('Y-m-d H:i:s',strtotime($nn[2].' '.$nn[3]))."' AND ms='".$nn[4]."')"); 
			if (!sql_result($ss1)) {deleteFiles($pathFn);}
			sql_close($ss1);		
		}
	}	
	sql_call("OPTIMIZE TABLE edomiLive.archivCamData");

	//System-Logs und mySQL und Apache leeren
	exec('rm -f /var/log/boot.log');
	exec('cat /dev/null > /var/log/lastlog');
	exec('cat /dev/null > /var/log/wtmp');
	exec('cat /dev/null > /var/log/log_http');
	exec('cat /dev/null > /var/log/log_mysql');
	exec('cat /dev/null > /var/log/log_mysql.err');
}

function saveServerIp() {
	//speichert die aktuelle Server-IP bei Änderung(!) in das KO[3]
	if (global_serverWANIP==1) {
		//Fritzbox abfragen
		$ip=fritzbox_GetWanIP();
		if ($ip!==false) {
			$n=getGADataFromID(3,2);
			if ($n['value']!=$ip) {writeGA(3,$ip);}
		}
	} else if (global_serverWANIP==2) {
		//Webdienst abfragen
		$ctx=stream_context_create(array('http'=>array('timeout'=>10))); 		//10 Sekunden Timeout
		$ip=file_get_contents('http://ipecho.net/plain',false,$ctx,0,15);		//max. 15 Zeichen lesen - URL ggf. anpassen
		if (filter_var($ip,FILTER_VALIDATE_IP)!==false) {
			$n=getGADataFromID(3,2);
			if ($n['value']!=$ip) {writeGA(3,$ip);}
		}
	} else if (global_serverWANIP==3) {
		//EDOMI-Server abfragen
		$ctx=stream_context_create(array('http'=>array('timeout'=>10))); 		//10 Sekunden Timeout
		$ip=file_get_contents('http://edomi.de/get_wanip.php',false,$ctx,0,15);	//max. 15 Zeichen lesen - URL ggf. anpassen
		if (filter_var($ip,FILTER_VALIDATE_IP)!==false) {
			$n=getGADataFromID(3,2);
			if ($n['value']!=$ip) {writeGA(3,$ip);}
		}
		
		
	}
}

function callServerHeartbeatURL() {
	//ruft per HTTP eine Heartbeat-URL auf
	//an die URL werden automatisch GET-Parameter angehängt: ?date=[dd.mm.YYYY]&time=[hh:mm:ss]
	if (!isEmpty(global_serverHeartbeat)) {
		$ctx=stream_context_create(array('http'=>array('timeout'=>10)));	//10 Sekunden Timeout
		$serverIP=file_get_contents(global_serverHeartbeat.'?date='.date('d.m.Y').'&time='.date('H:i:s'),false,$ctx,0,1);	//max. 1 Zeichen lesen
	}
}

function saveProject($fn) {
	//Speichert/Exportiert das aktuelle Projekt
	//$fn: Dateiname mit relativem Pfad (ab MAIN_PATH)
	writeToLog(0,true,'Projekt archivieren/herunterladen: '.basename($fn));

	//Projekt-Versionierung (aktuell nur EDOMI-Version speichern, um beim Öffnen eines Archivs kontrollierte DB-Änderungen vornehmen zu können)
	if (sql_tableExists('edomiProject.editProjectInfo')) {
		sql_call("UPDATE edomiProject.editProjectInfo SET edomiversion='".global_version."' WHERE id=1");
	} else {
		sql_call("CREATE TABLE edomiProject.editProjectInfo (id BIGINT UNSIGNED DEFAULT NULL,edomiversion VARCHAR(30) DEFAULT NULL,projectversion VARCHAR(30) DEFAULT NULL,KEY (id)) ENGINE=MyISAM DEFAULT CHARSET=latin1");
		sql_call("INSERT INTO edomiProject.editProjectInfo (id,edomiversion) VALUES (1,'".global_version."')");
	}

	exec('tar -cf "'.MAIN_PATH.$fn.'" '.MAIN_PATH.'/www/data/project');

	sql_call("FLUSH TABLES ".sql_getAllTables(false,'Project'));
	exec('tar -rf "'.MAIN_PATH.$fn.'" '.MYSQL_PATH.'/edomiProject');
	sql_call("UNLOCK TABLES");

	//Adminseite mitteilen, dass das Projekt gespeichert wurde
	createInfoFile(MAIN_PATH.'/www/data/tmp/projectsaveready.txt',array('ok'));
}

function loadProject($fn) {
	//$fn: Dateiname ohne Pfad (muss im Verzeichnis MAIN_PATH/www/data/projectarchiv liegen)
	if (file_exists(MAIN_PATH.'/www/data/projectarchiv/'.$fn)) {
		writeToLog(0,true,'Projekt öffnen: '.$fn);

		//Zielordner leeren/löschen
		deleteFiles(MAIN_PATH.'/www/data/project/*.*');
		deleteFiles(MAIN_PATH.'/www/data/project/visu/img/*.*');
		deleteFiles(MAIN_PATH.'/www/data/project/visu/etc/*.*');

		sql_call("FLUSH TABLES ".sql_getAllTables(false,'Project'));
		exec('rm -rf '.MYSQL_PATH.'/edomiProject');
		exec('tar -xf "'.MAIN_PATH.'/www/data/projectarchiv/'.$fn.'" -C /');
		sql_call("UNLOCK TABLES");

		//EDOMI-Version des archivierten Projekts prüfen und Updates anwenden
		//	(Projekte älter als 1.19 enthalten noch keine EDOMI-Version, d.h. es werden alle Updates angewendet)
		$version=sql_getValue('edomiProject.editProjectInfo','edomiversion','id=1');
		if (!is_numeric($version)) {$version='0';}	//keine Versionsinfo verfügbar => Projekt wurde vor 1.19 erstellt
		$version=floatVal($version);
		$tmp=edomi_update($version,false);
		if (!isEmpty($tmp)) {writeToLog(0,true,'Projekt '.$fn.': Update auf EDOMI-Versionen '.$tmp);}

		//Adminseite mitteilen, dass das Projekt geladen wurde
		createInfoFile(MAIN_PATH.'/www/data/tmp/projectloadready.txt',array('ok'));
	}
}

?>
