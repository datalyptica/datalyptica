package main

import (
	"html/template"
	"log"
	"net/http"
	
	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()
	
	// Load template explicitly
	tmpl, err := template.ParseFiles("web/templates/installer/index.html")
	if err != nil {
		log.Fatalf("Template loading error: %v", err)
	}
	r.SetHTMLTemplate(tmpl)
	
	r.GET("/", func(c *gin.Context) {
		c.HTML(http.StatusOK, "index.html", gin.H{
			"Title": "ShuDL Data Lakehouse Installer",
			"Version": "v1.0.0", 
			"Description": "Test installer",
		})
	})
	
	log.Println("Starting minimal test server on :8097")
	r.Run(":8097")
}
