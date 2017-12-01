v.net --verbose input=dub30_exp_thu points=nodes out=streets_net operation=connect threshold=10 --overwrite
v.net.path input=streets_net output=path arc_column=length file=shortestpath_locations --overwrite
v.net.path input=streets_net output=path2 arc_column=u08_00 file=shortestpath_locations --overwrite
v.db.addcolumn streets_net column="time_0800 double precision"
v.db.update streets_net col="time_0800" qcol="(1.0*length)/(1.0*u08_00)" #Note: length is in metres and u08_00 is in km/h
v.net.path input=streets_net output=path3 arc_column=time_0800 file=shortestpath_locations --overwrite
