
module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")

    browserify:
      development:
        files:
          'build/compiled-dev.js': ['src/main.coffee']
        options:
          browserifyOptions:
            extensions: ['.coffee', '.js']
          transform: ['coffeeify', ['envify', NODE_ENV: 'development']]

      production:
        files:
          'build/compiled-prod.js': ['src/main.coffee']
        options:
          browserifyOptions:
            extensions: ['.coffee', '.js']
          transform: ['coffeeify', ['envify', NODE_ENV: 'production']]

      tests:
        files:
          'compiled/all-tests.js': ['src/main.coffee', 'test/test_helper.coffee', 'test/*.coffee']
        options:
          browserifyOptions:
            extensions: ['.coffee', '.js']
          transform: ['coffeeify']

    watch:
      grunt:
        files: ["Gruntfile.coffee"]

      main:
        files: ["src/*.coffee"]
        tasks: ["compile"]

      tests:
        files: ["test/*.coffee", "src/*.coffee", "src/**/*.js"]
        tasks: ["browserify:tests"]

    mocha:
      all:
        src: ['test/runner.html']
      options:
        run: true
        log: true
        reporter: 'Spec'

  grunt.loadNpmTasks('grunt-browserify');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-mocha');
  grunt.loadNpmTasks "grunt-contrib-watch"


  grunt.registerTask "compile", ["browserify:development", "browserify:production"]

  grunt.registerTask "test", ["browserify:tests", "mocha"]

  grunt.registerTask "default", ["browserify", "watch"]
