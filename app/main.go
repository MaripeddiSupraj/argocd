package main

import (
	"fmt"
	"net/http"
	"rsc.io/quote"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, quote.Hello())
	})

	fmt.Println("Server listening on port 8080")
	http.ListenAndServe(":8080", nil)
}