my @holy = ("Las Vegas","Leopard","Levitation","Liftoff","Living End","Lodestone","Long John Silver","Looking Glass","Love Birds","Luther Burbank");
while (1) {
  for (0..$#holy) {
    my $holy = $holy[$_];
    if (rand > 0.9) {
      print "Holy $holy[$_]!\n";
    } else {
      sleep (1);
    }
  }
}
