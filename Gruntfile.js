module.exports = function (grunt) {

    const SCRIPT_DIRECTORY = 'scripts';
    const MIGRATIONS_DIRECTORY = 'migrations';
    const MIGRATIONS_TABLE = 'migrations';

    grunt.initConfig({
        shell: {
            migrations: {
                options: {
                    stdout: true,
                    stderr: true,
                },
                command: action => [
                    `export MIG_DIR=${MIGRATIONS_DIRECTORY}`,
                    `export MIG_TABLE=${MIGRATIONS_TABLE}`,
                    `./${SCRIPT_DIRECTORY}/migrations.sh ${action}`
                ].join(';'),
            },
        }
    });

    grunt.registerTask(
        'migrations:init',
        'Migrations - initialisation',
        function () {
            grunt.loadNpmTasks('grunt-shell');

            grunt.task.run('shell:migrations:init');
        }
    );

    grunt.registerTask(
        'migrations:up',
        'Migrations - effectue la prochaine migration disponible',
        function () {
            grunt.loadNpmTasks('grunt-shell');

            grunt.task.run(`shell:migrations:up`);
        }
    );

    grunt.registerTask(
        'migrations:down',
        'Migrations - annule la dernière migration',
        function () {
            grunt.loadNpmTasks('grunt-shell');

            grunt.task.run(`shell:migrations:down`);
        }
    );

    grunt.registerTask(
        'migrations:create',
        'Migrations - crée les fichiers de migration',
        function () {
            grunt.loadNpmTasks('grunt-shell');

            grunt.task.run(`shell:migrations:create`);
        }
    );

    grunt.registerTask(
        'migrations',
        'Migrations - effectue les prochaines migrations disponibles dans l\'ordre',
        function () {
            grunt.loadNpmTasks('grunt-shell');

            grunt.task.run(`shell:migrations:latest`);
        }
    );
};
