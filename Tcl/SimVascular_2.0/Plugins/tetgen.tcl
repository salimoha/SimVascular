#===========================================================================
#    
# Copyright (c) 2014-2015 The Regents of the University of California.
# All Rights Reserved. 
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including 
# without limitation the rights to use, copy, modify, merge, publish, 
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
# 
# The above copyright notice and this permission notice shall be included 
# in all copies or substantial portions of the Software.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
# OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#===========================================================================    

# Procedure: guiMMcreateTetGenScriptFile
proc guiMMcreateTetGenScriptFile {} {

  global gFilenames
  global guiMMvars
  global guiTGvars
  global gOptions

  set mesh_kernel $gOptions(meshing_kernel)

  if {$mesh_kernel == "TetGen"} {
    set scriptfile [file rootname $gFilenames(polydata_solid_file)].tgs
  } else {
    return -code error "ERROR: Invalid Mesh Script File"
  }
  set gFilenames(tet_mesh_script_file) $scriptfile

  set basename [file rootname [file tail $gFilenames(tet_mesh_script_file)]]

  puts "Writing attribute file $scriptfile."

  set fp [open $scriptfile "w"]

  puts $fp "# geodesic_tetGen_script 1.0"

  puts $fp "#"

  puts $fp "# create log"
  puts $fp "logon $basename.logfile"
  puts $fp "# load solid model"
  puts $fp "loadModel $gFilenames(polydata_solid_file)"
  puts $fp "# if Using the centerlines of the solid. Extract Centerlines"
  puts $fp "#set solid model of the mesh object"
  puts $fp "setSolidModel"

#  puts $fp "# create a new mesh object"
#  puts $fp "newMesh"
  puts $fp "# control options"

  puts $fp "option surface $guiMMvars(meshGenerateSurfaceMesh)"
  puts $fp "option volume $guiMMvars(meshGenerateVolumeMesh)"

  puts $fp "# start_of_user_meshing_control_parameters"
  if {$guiTGvars(useMeshMaxVolume)} {
    puts $fp "option a $guiTGvars(meshMaxEdgeSize)"
  }
  if {[llength $guiTGvars(wallFaces)] != 0} {
    set guiTGvars(meshWallFirst) 1
    puts $fp "wallFaces [lrange $guiTGvars(wallFaces) 0 end]"
  } else {
    set guiTGvars(meshWallFirst) 0
  }
  if {$guiTGvars(useCenterlineRadius)} {
    puts $fp "useCenterlineRadius"
  }
  if {$guiTGvars(useFunctionBasedMeshing)} {
    puts $fp "functionBasedMeshing $guiTGvars(meshMaxEdgeSize) $guiTGvars(functionBasedMeshingName)"
  }
  if $guiMMvars(meshGenerateBoundaryLayerMesh) {
    puts $fp "boundaryLayer $guiTGvars(numsublayers) $guiTGvars(blthicknessratio) $guiTGvars(sublayerratio)" 
  }
  # strip out blank lines
  set broke [split $guiTGvars(meshControlAttributes) "\n"]
  for {set i 0} {$i < [llength $broke]} {incr i} {
    set trimed [string trim [lindex $broke $i]]
    if {$trimed != ""} {
      puts $fp $trimed
    }
  }
  #if {$guiTGvars(useSphereRefinement)} {
  #  puts $fp "sphereRefinement $guiTGvars(refinementSize) $guiTGvars(sphereRadius) $guiTGvars(sphereCenter)"
  #}
  if {$guiTGvars(useMeshOptimization)} {
    puts $fp "option O $guiTGvars(meshOptimization)"
  }
  if {$guiTGvars(useMeshTolerance)} {
    puts $fp "option T $guiTGvars(meshTolerance)"
  }
  if {$guiTGvars(useMeshQuality)} {
    puts $fp "option q $guiTGvars(meshQuality)"
  }
  if {$guiTGvars(useMeshCoarsen)} {
    puts $fp "option R $guiTGvars(meshCoarsenPercent)"
  }
  if {$guiTGvars(useMeshSuppression)} {
    puts $fp "option Y"
  }
  if {$guiTGvars(useNoMerging)} {
    puts $fp "option M"
  }
  if {$guiTGvars(useMeshDetection)} {
    puts $fp "option d"
  }
  if {$guiTGvars(useCheckConsistency)} {
    puts $fp "option C"
  }
  if {$guiTGvars(useQuiet)} {
    puts $fp "option Q"
  }
  if {$guiTGvars(useVerbose)} {
    puts $fp "option V"
  }
  if {$guiTGvars(useMeshTetGenOptions)} {
    puts $fp "option $guiTGvars(meshTetGenOptions)"
  }

  puts $fp "# end_of_user_meshing_control_parameters"

  puts $fp "generateMesh" 

  if {$guiMMvars(meshGenerateBoundaryLayerMesh)} {
    puts $fp "# create and name boundaries for boundary layer mesh"
    puts $fp "getBoundaries"  
  }

  puts $fp "# write out mesh"
    
  set gFilenames(mesh_file) [file rootname $gFilenames(mesh_file)].vtu
  puts $fp "writeMesh $gFilenames(mesh_file) vtu 0"

  puts $fp "# clean up and shut down"
  puts $fp "deleteMesh"
  puts $fp "deleteModel"
  puts $fp "logoff"

  close $fp
}

proc mesh_readTGS {filename resObj} {
  global gOptions
  puts $gOptions(meshing_kernel)
  #@author Adam Updegrove
  #@c This function processes a tetgen style meshing
  #@c script file.
  #@a filename:  script filename.
  #@a resObj:  resulting repository MeshObject.
  #@note resObj is not deleted, even if the script file
  #@note specifies deleteModel and deleteMesh.

  if {[repos_exists -obj $resObj] != 0} {
    return -code error "object $resObj already exists!"
  }

  set solid /tmp/mesh_readTGS/solid
  catch {repos_delete -obj $solid}

  global guiMMvars
  global smasherInputName
  global gInputReturnVar
  global PickedAssembly
  global guiPDvars
  global guiTGvars

  puts $gOptions(meshing_kernel)

  # lookup for type
  set types(1) 1
  set types(2) 2
  set types(absolute) 1
  set types(relative) 2
  set types(abs) 1
  set types(rel) 2
  set sides(negative) 0
  set sides(positive) 1
  set sides(both) 2
  set sides(0) 0
  set sides(1) 1
  set sides(2) 2

  mesh_setKernel -name $gOptions(meshing_kernel)
  mesh_newObject -result $resObj
  $resObj SetSolidKernel -name $gOptions(meshing_solid_kernel)

  set fp [open $filename r]
  while {[gets $fp line] >= 0} {
      set line [string trim $line]
      # skip comment lines
      if {[string index $line 0] == "\#"} {
         puts "ignoring line: <$line>"
         continue
      }
      puts "line: $line"
      # supported commands
      if {[lindex $line 0] == "logon"} {
         mesh_logon -file [lindex $line 1]
      } elseif {[lindex $line 0] == "logoff"} {
         mesh_logoff
      } elseif {[lindex $line 0] == "newMesh"} {
        $resObj NewMesh
      } elseif {[lindex $line 0] == "generateMesh"} {
        $resObj GenerateMesh
      } elseif {[lindex $line 0] == "loadModel"} {
        $resObj LoadModel -file [lrange $line 1 end]
        catch {repos_delete -obj $solid}
        solid_readNative -file [lrange $line 1 end] -obj $solid
	#set smasherInputName $solid
	if {$gOptions(meshing_solid_kernel) == "PolyData"} {
           global gPolyDataFaceNames
           global gPolyDataFaceNamesInfo
           catch {unset gPolyDataFaceNames}
           catch {unset gPolyDataFaceNamesInfo}
	   if [file exists [lrange $line 1 end].facenames] {
	     puts "sourcing [lrange $line 1 end].facenames"
	     source [lrange $line 1 end].facenames
             package require md5
	     set mymd5 [::md5::md5 -hex -file [lrange $line 1 end]]
             #if {$mymd5 != $gPolyDataFaceNamesInfo(model_file_md5)} {
	     #  return -code error "ERROR: polydata model ([lrange $line 1 end]) file doesn't match one used to generate facenames ([lindex $line 1].facenames)!"
             #}
	   } else {
	     puts "Getting Solid Boundaries..."
	     set gInputReturnVar 50.0
	     set dummyNum [tk_inputDialog .askthem "Boundary Extraction" "Enter Boundary Extraction Angle (0-90 degrees):" question 0 "OK"] 
	     set guiPDvars(angleForBoundaries) $gInputReturnVar
	     $solid GetBoundaryFaces -angle $gInputReturnVar
	     puts "Got Boundaries"

             set allids [$solid GetFaceIds]
	     set numfaces [llength $allids]
             set yesno [tk_messageBox -message "The number of surfaces found was: $numfaces.  Is this the correct number of surfaces on your polydata?" -default no -icon question -type yesno]
	     if {$yesno == "no"} {
	       return -code error "Try again with a different boundary extraction angle or check the surface of the polydata for deteriorated elements."
	     }
             foreach newid $allids {
               set gPolyDataFaceNames($newid) "noname_$newid"
             }
           }
	}
      } elseif {[lindex $line 0] == "setSolidModel"} {
          set solidPD /tmp/solid/pd
          catch {repos_delete -obj $solidPD}

	  #Set the polydatasolid in the mesh object to the current solid model
	  $solid GetPolyData -result $solidPD
          $resObj SetVtkPolyData -obj $solidPD

      } elseif {[lindex $line 0] == "localSize"} {
	set facename [lindex $line 1] 
	if {$facename == ""} {
	  return -code error "ERROR: Must select a face to add local mesh size on !"
	}
	set faceids [$solid GetFaceIds]
	foreach id $faceids {
	  if {$gPolyDataFaceNames($id) == $facename} {
	    set regionid $id
	  }
	}
	$resObj SetLocalSize -id $regionid -type [lindex $line 2] -size [lindex $line 3] 
      } elseif {[lindex $line 0] == "useCenterlineRadius"} {
	if {$guiTGvars(meshWallFirst) != 1} {
          return -code error "ERROR: Must select wall faces for boundary layer"
	}
	set cappedsolid /tmp/solid/cappedpd
	catch {repos_delete -obj $cappedsolid}

	set cappedsolid [PolyDataVMTKGetCenterIds $resObj mesh] 
	set polys [PolyDataVMTKCenterlines $cappedsolid $resObj mesh]

	$resObj SetVtkPolyData -obj [lindex $polys 0]
	
      } elseif {[lindex $line 0] == "functionBasedMeshing"} {
	$resObj SetSizeFunctionBasedMesh -size [lindex $line 1] -functionname [lindex $line 2]
      } elseif {[lindex $line 0] == "sphereRefinement"} {
	$resObj SetSphereRefinement -size [lindex $line 1] -r [lindex $line 2] -ctr [lrange $line 3 5]
      } elseif {[lindex $line 0] == "wallFaces"} {
	set guiTGvars(meshWallFirst) 1
	$resObj SetMeshOptions -options "k" -value 0
	set walls {}
	for {set i 1} {$i < [llength $line]} {incr i} {
	  set name [lindex $line $i]
	  set name_id [return_face_id $solid $name]
	  puts "name_id: $name_id"
	  lappend walls $name_id
	}
	$resObj SetWalls -walls $walls
      } elseif {[lindex $line 0] == "boundaryLayer"} {
	if {$guiTGvars(meshWallFirst) != 1} {
          return -code error "ERROR: Must select wall faces for boundary layer"
	}
        $resObj SetBoundaryLayer -id 0 -type 0 -side 0 -nL [lindex $line 1] -H [lrange $line 2 3]
      } elseif {[lindex $line 0] == "tolerance"} {
        $resObj SetTolerance -tolerance [lindex $line 1]
      } elseif {[lindex $line 0] == "quality"} {
        $resObj SetQuality -quality [lindex $line 1]
      } elseif {[lindex $line 0] == "writeMesh"} {
        $resObj WriteMesh -file "[lrange $line 1 end-2]" -version [lindex $line end]
      } elseif {[lindex $line 0] == "option"} {
	  if {[llength $line] == 3} {
	     if {[lindex $line 1] == "surface"} {
               $resObj SetSurfaceMeshFlag -value [lindex $line 2]
	     } elseif {[lindex $line 1] == "volume"} {
               $resObj SetVolumeMeshFlag -value [lindex $line 2]
     	     } else {
	       $resObj SetMeshOptions -options [lindex $line 1] -value [lindex $line 2]
       	    }
	  } else {
             foreach lineval [lrange $line 1 end] {
              $resObj SetMeshOptions -options $lineval
             }
	  }
      } elseif {[lindex $line 0] == "getBoundaries"} {
        $resObj GetBoundaryFaces -angle $guiPDvars(angleForBoundaries)

      } else {
        puts "ignoring line: <$line>"
      }
  }
  close $fp
  catch {repos_delete -obj $solid}
}

# Procedure: createSolidBoundaires
proc createSolidBoundaries {} {

  global gFilenames
  global gObjects
  global gOptions
  global gRen3d
  global guiMMvars
  global guiPDvars
  global gPolyDataFaceNames

  set filename $gFilenames(polydata_solid_file)
  set object $gObjects(polydata_solid)

  if {[file exists $filename] == 0} {
    puts "ERROR: File $filename does not exist."
    return -code error "ERROR: File $filename does not exist."
  }
  

  if {[file exists $filename.facenames] == 0} {
    puts "Getting Solid Boundaries..."
    $object GetBoundaryFaces -angle $guiPDvars(angleForBoundaries)
    puts "GotBoundaries"

    set allids [$object GetFaceIds]
    foreach id $allids {
      set gPolyDataFaceNames($id) "noname_$id"
    }
  }

  set pretty_names {}
  foreach i [$object GetFaceIds] {
    lappend pretty_names $gPolyDataFaceNames($i)
  }
  if {[llength [lsort -unique $pretty_names]] != [llength $pretty_names]} {
    set duplist [lsort -dictionary $pretty_names]
    foreach i [lsort -unique $pretty_names] {
      set idx [lsearch -exact $duplist $i]
      set duplist [lreplace $duplist $idx $idx]
    }
    set msg "Duplicate faces found!\n\n"
    foreach dup $duplist {
      set msg "$msg  name: $dup\n"
    }
    tk_messageBox -title "Duplicate Face Names" -type ok -message $msg
  }

}

proc PickPolyDataFaces {solid} {
  global gInputReturnVar
  set gInputReturnVar 1

  set dummyNum [tk_inputDialog .askthem "Enter Inlet Surface" "Enter Number of Inlet Surfaces:" question 0 "OK"] 
  tk_messageBox -title "Select Face" -type ok -message "To select a face click on 3D viewing window, hold cursor over surface and click 'p'"
  set numInlets $gInputReturnVar
  for {set tot 1} {$tot <= $numInlets} {incr tot} {
    PickPolyDataFace "inlet"
  }
  set gInputReturnVar 1
  set dummyNum [tk_inputDialog .askthem "Enter Outlet Surface" "Enter Number of Outlet Surfaces:" question 0 "OK"] 
  set numOutlets $gInputReturnVar
  for {set tot 1} {$tot <= $numOutlets} {incr tot} {
    PickPolyDataFace "outlet"
  }
  set gInputReturnVar 1
  set dummyNum [tk_inputDialog .askthem "Enter Wall Surface" "Enter Number of Wall Surfaces:" question 0 "OK"] 
  set numWalls $gInputReturnVar
  for {set tot 1} {$tot <= $numWalls} {incr tot} {
    PickPolyDataFace "wall"
  }
}

proc PickPolyDataFace {facetype} {
  global gActorPicked
  global gPolyDataFaceNames
  global PickedAssembly
  global gInputReturnVar
  
  set gInputReturnVar ""
  set gActorPicked 0

  vwait gActorPicked
  #This is the id Number of the picked actor!
  set idNumber [file tail $PickedAssembly]

  if {$facetype == "inlet"} {
  set useDefault [tk_inputDialog .askthem "INLET" "Enter what to use for inlet face or use default face name:" question 0 "Use Face Name" "Use Default Name"]
  } elseif {$facetype == "outlet"} {
  set useDefault [tk_inputDialog .askthem "OUTLET" "Enter what to use for outlet face or use default face name:" question 0 "Use Face Name" "Use Default Name"]
  } elseif {$facetype == "wall"} {
  set useDefault [tk_inputDialog .askthem "WALL" "Enter what to use for wall face or use default face name:" question 0 "Use Face Name" "Use Default Name"]
  }
  if {$useDefault == 1} {
    if {$facetype == "inlet"} {
      set gPolyDataFaceNames($idNumber) "inlet_$idNumber"  
    } elseif {$facetype == "outlet"} {
      set gPolyDataFaceNames($idNumber) "outlet_$idNumber" 
    } elseif {$facetype == "wall"} {
      set gPolyDataFaceNames($idNumber) "wall_$idNumber" 
    }
  } elseif {$useDefault == 0} {
    puts $gInputReturnVar
    if {$facetype == "inlet"} {
      set gPolyDataFaceNames($idNumber) $gInputReturnVar  
    } elseif {$facetype == "outlet"} {
      set gPolyDataFaceNames($idNumber) $gInputReturnVar 
    } elseif {$facetype == "wall"} {
      set gPolyDataFaceNames($idNumber) $gInputReturnVar 
    }
    puts "Name has been changed to $gPolyDataFaceNames($idNumber)"
  }
  set gActorPicked 0
}

# Procedure: guiTGmeshQuality
proc guiTGmeshQuality { quality} {
  global guiTGvars
  set guiTGvars(meshQuality) $quality
}

# Procedure: guiTGmeshOptimization
proc guiTGmeshOptimization { optimization} {
  global guiTGvars
  set guiTGvars(meshOptimization) $optimization
}

# Procedure: guiTGmeshCoarsen
proc guiTGmeshCoarsenPercent { percent} {
  global guiTGvars
  set guiTGvars(meshCoarsenPercent) $percent
}

proc guiTETGENvis {type} {

  global gRenWin_3D_vars
  global guiTGvars
  global gRen3d
  global gObjects
  global gOptions
  global smasherInputName
  global gInteractorRen

  set object $gObjects(polydata_solid)
  set useLOD $gRenWin_3D_vars(solid_use_LOD)
  set smasherInputName $object
  
  set solid /solid/sphereinteractor/pd
#  set solid /gRenWin_3D/meshing_solid/pd
  if {[repos_exists -obj $object] == 1} {
     catch {repos_delete -obj $solid}
     if {$gOptions(facet_max_edge_size) == ""} {
       $object GetPolyData -result $solid
     } else {
       $object GetPolyData -result $solid  -max_edge_size $gOptions(facet_max_edge_size)
     }

     if {$useLOD == 1} {
       vis_lodRepos $gRen3d $solid
     } else {
       vis_pRepos $gRen3d $solid
     }
  }
  set ren $gRen3d

#  global gRen3dFreeze
#  if {$gRen3dFreeze > 0} {
#    set alreadyfrozen 1
#  } else {
#    set alreadyfrozen 0
#    set gRen3dFreeze 1
#  }

  if {$type == "sphere"} {
    if {$guiTGvars(showSphere) == 0} {
      catch {vis_sphereWidgetRm $gRen3d guiREFINE}
    } else {
      catch {vis_sphereWidgetRm $gRen3d guiREFINE}
      vis_sphereWidgetAdd $gRen3d [repos_exportToVtk -src $solid] guiREFINE guiREFINEsphereEnableInteraction guiREFINEsphereBeginInteraction guiREFINEsphereInteract guiREFINEsphereEndInteraction
      vis_sphereWidgetOn $gRen3d guiREFINE
      vis_sphereWidgetScaleOn $gRen3d guiREFINE
      set guiTGvars(sphereCenter) [vis_sphereWidgetGetCenter $gInteractorRen guiREFINE]
      set guiTGvars(sphereRadius) [expr {double(round(10000*[vis_sphereWidgetGetRadius $gInteractorRen guiREFINE]))/10000}]
      set guiTGvars(setSphereRadius) [expr {double(round(10000*[vis_sphereWidgetGetRadius $gInteractorRen guiREFINE]))/10000}]
    }
  }

#  if {$alreadyfrozen == 0} {
#    set gRen3dFreeze 0
#    vis_render $ren
#  }
  crd_ren gRenWin_3D_ren1
  smasherGUIupdateViewWindow
}

proc guiREFINEsphereEnableInteraction {} {
  global gInteractorInteracting
  set gInteractorInteracting 0
  global gInteractorRen
}

proc guiREFINEsphereBeginInteraction {} {
  global gInteractorInteracting
  set gInteractorInteracting 1
}

proc guiREFINEsphereInteract {} {
  global gInteractorRen
  global guiTGvars
  set guiTGvars(sphereBounds) [vis_sphereWidgetGetBB $gInteractorRen guiREFINE]
  set guiTGvars(sphereCenter) [vis_sphereWidgetGetCenter $gInteractorRen guiREFINE]
  set guiTGvars(sphereRadius) [expr {double(round(10000*[vis_sphereWidgetGetRadius $gInteractorRen guiREFINE]))/10000}]
}

proc guiREFINEsphereEndInteraction {} {
  global gInteractorInteracting
  set gInteractorInteracting 0
}

proc guiREFINEsetRefineSphereRadius {} {
  global gInteractorRen
  global guiTGvars
  global gRen3d

  set guiTGvars(sphereRadius) $guiTGvars(setSphereRadius)
  vis_sphereWidgetSetRadius $gInteractorRen guiREFINE $guiTGvars(setSphereRadius)
  vis_render $gRen3d
}

proc guiMMreadTetGenScriptFile {} {
  global symbolicName
  global gFilenames
  global gObjects
  global guiMMvars
  global guiPDvars
  global guiTGvars
  global gOptions

  set fp [open $gFilenames(tet_mesh_script_file) "r"]

  set guiMMvars(meshControlAttributes) {}

  while {[gets $fp line] >=0 } {

     set line [string trim $line]
     catch {set cmd [lindex $line 0]}
     puts $line

     if {$line == ""} {
       # just skip blank line
     } elseif {[string index $line 0] == "#"} {
       # don't preserve comment lines
       #set guiMMvars(meshControlAttributes) "$guiMMvars(meshControlAttributes) $line\n"
     } elseif {$cmd == "newMesh"} {
       # automatically generated
     } elseif {$cmd == "loadModel"} {
       set gFilenames(polydata_solid_file) [lindex $line 1]
       guiFNMloadSolidModel polydata_solid_file polydata_solid
       # should we check that the solid model exists here?
     } elseif {$cmd == "msinit"} {
       # automatically generated
     } elseif {$cmd == "msinitbl"} {
       # automatically generated if needed
     } elseif {$cmd == "msexit"} {
       # automatically generated
     } elseif {$cmd == "memoff"} {
       # ignore
       set guiMMvars(meshControlAttributes) "$guiMMvars(meshControlAttributes) #IGNORED: $line\n"
     } elseif {$cmd == "deleteMesh"} {
       # automatically generated
     } elseif {$cmd == "deleteModel"} {
       # automatically generated
     } elseif {$cmd == "writeSMS"} {
       puts "WARNING:  writeSMS not compatible with Geodesic."
       puts "          Converting call from writeSMS to writeMesh."
       set guiMMvars(meshControlAttributes) "$guiMMvars(meshControlAttributes) #WARNING: converted writeSMS to writeMesh.\n"
       set gFilenames(mesh_file) [lindex $line 1]
     } elseif {$cmd == "writeMesh"} {
       set gFilenames(mesh_file) [lindex $line 1]
     } elseif {$cmd == "writeStats"} {
       set guiMMvars(meshWriteMeshStats) 1
       # what about the filename?
     } elseif {$cmd  == "option"} {
       # now process configuration options
       if {[lindex $line 1] == "surface"} {
         if { [lindex $line 2] == 1} {
	   set guiMMvars(meshGenerateSurfaceMesh) 1
         } elseif { [lindex $line 2] == 0} {
	   set guiMMvars(meshGenerateSurfaceMesh) 0
	 }
       } elseif {[lindex $line 1] == "volume"} {
	 if {[lindex $line 2] == 1} {
	   set guiMMvars(meshGenerateVolumeMesh) 1
         } elseif {[lindex $line 2] == 0} {
	   set guiMMvars(meshGenerateVolumeMesh) 0
	 }
       } elseif {[lindex $line 1] == "a"} {
          set guiTGvars(useMeshMaxVolume) 1
	  set guiTGvars(meshMaxEdgeSize) [lindex $line 2]
       } elseif {[lindex $line 1] == "O"} {
          set guiTGvars(useMeshOptimization) 1
	  set guiTGvars(meshOptimization) [lindex $line 2]
       } elseif {[lindex $line 1] == "T"} {
          set guiTGvars(useMeshTolerance) 1
	  set guiTGvars(meshTolerance) [lindex $line 2]
       } elseif {[lindex $line 1] == "q"} {
          set guiTGvars(useMeshQuality) 1
	  set guiTGvars(meshQuality) [lindex $line 2]
       } elseif {[lindex $line 1] == "R"} {
          set guiTGvars(useMeshCoarsen) 1
	  set guiTGvars(meshCoarsen) [lindex $line 2]
       } elseif {[lindex $line 1] == "Y"} {
          set guiTGvars(useMeshSuppression) 1
       } elseif {[lindex $line 1] == "M"} {
          set guiTGvars(useNoMerging) 1
       } elseif {[lindex $line 1] == "d"} {
          set guiTGvars(useMeshDetection) 1
       } elseif {[lindex $line 1] == "C"} {
          set guiTGvars(useCheckConsistency) 1
       } elseif {[lindex $line 1] == "C"} {
          set guiTGvars(useCheckConsistency) 1
       } elseif {[lindex $line 1] == "Q"} {
          set guiTGvars(useQuiet) 1
       } elseif {[lindex $line 1] == "V"} {
          set guiTGvars(useVerbose) 1
       } else {
          puts "ERROR: line $line ignored in meshSim script file."
       }
     } elseif {$cmd == "boundaryLayer"} {
       set guiMMvars(meshGenerateBoundaryLayerMesh) 1
       set guiMMvars(mca_id) [lindex $line 1]
       set guiTGvars(numsublayers) [lindex $line 2]
       set guiTGvars(blthicknessratio) [lindex $line 3]
       set guiTGvars(sublayerratio) [lindex $line 4]
     } elseif {$cmd == "functionBasedMeshing"} {
       set guiTGvars(useFunctionBasedMeshingName) 1
       set guiTGvars(functionBasedMeshingName) [lindex $line 2]
     } elseif {$cmd == "sphereRefinement"} {
       set guiTGvars(useSphereRefinement) 1
       guiTETGENvis "sphere"
       set guiTGvars(refinementSize) [lindex $line 1]
       set guiTGvars(sphereRadius) [lindex $line 2]
       set guiTGvars(setSphereRadius) [lindex $line 2]
       set guiTGvars(sphereCenter) [lrange $line 3 5]
       guiREFINEsetRefineSphereRadius
     } elseif {$cmd == "logon"} {
       # automatically generated
     } elseif {$cmd == "logoff"} {
       # automatically generated
     } else {
       puts "ERROR:  line $line ignored from meshSim script file."
     }
  }
  close $fp
}

proc return_face_id {solid facename} {
  global gPolyDataFaceNames
  set wallid -1

  set faceids [$solid GetFaceIds]
  foreach id $faceids {
    if {$gPolyDataFaceNames($id) == $facename} {
      set wallid $id
    }
  } 
  return $wallid
}