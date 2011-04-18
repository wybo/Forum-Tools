#!/usr/bin/env r
#
# script that reads a pajek file and calculates shortest path
# distances

if (is.null(argv) | length(argv) < 1) {
  cat("Need .net file as argument\n")
  q()
} else {
  file_name = argv[1]
}

require(igraph, quietly=TRUE)
require(MASS, quietly=TRUE)

netw = read.graph(file_name, format="pajek")
matr = shortest.paths(netw)
write.matrix(matr)
