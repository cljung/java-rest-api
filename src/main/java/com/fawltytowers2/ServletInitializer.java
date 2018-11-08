package com.fawltytowers2;

import java.util.logging.Level;
import java.util.logging.Logger;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.builder.SpringApplicationBuilder;

public class ServletInitializer extends SpringBootServletInitializer {

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
        System.out.println ( "*** SpringApplicationBuilder() ***");
        Logger lgr = Logger.getLogger(Application.class.getName());
        lgr.info( "SpringApplicationBuilder called..." );
        // pre-load the PostgreSQL db driver
        try {
            Class.forName("org.postgresql.Driver");
            lgr.info( "Registered PostGreSQL Driver org.postgresql.Driver");
        } catch ( java.lang.ClassNotFoundException ex ) {
            lgr.log(Level.SEVERE, ex.getMessage(), ex);
        }
        return builder.sources(Application.class);
    }
}

