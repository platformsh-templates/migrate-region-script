<?php

/**
 * Prerequisites:
 * - "aws" cli installed and configured with access to backup bucket
 * - "platform" cli installed and configured with access to project variables
 * - "BACKUP_ENVVAR_ENCRYPTION_SECRET", "BACKUP_ENVVAR_S3_DIRECTORY" environment variables defined. Or, script executed with argument.
 */
final class EnvvarBackup
{
    const ENCRYPTION_SECRET_VARNAME = 'BACKUP_ENVVAR_ENCRYPTION_SECRET';
    const S3_DIRECTORY_VARNAME = 'BACKUP_ENVVAR_S3_DIRECTORY';
    const ENCRYPTION_METHOD_MAIN = 'AES-256-GCM';
    const ENCRYPTION_METHOD_FALLBACK = 'AES-256-CBC';

    private $dryRun;
    private $secret;
    private $s3dir;
    private $outputFile;
    private $tempDir = '/tmp';

    public function __construct($options)
    {
        $this->dryRun = isset($options['dry-run']);
        $this->outputFile = isset($options['output-file']);
        $this->loadTmpDir($options);
        $this->loadSecret($options);
        $this->loadS3Destination($options);
    }

    public function run()
    {
        $encryptedJson = $this->encrypt(
            $this->getJsonToBackup()
        );
        if ($this->outputFile) {
            echo $encryptedJson;
        }
        if ($this->s3dir) {
            $this->storeToS3($encryptedJson);
        }
    }

    private function getJsonToBackup(): string
    {
        $varsFromCli = array_map(static function ($line) {
            return explode(',', $line, 3);
        }, array_filter(
            explode("\n", shell_exec('platform variables --format=csv --no-header'))
        ));

        $parsedVars = [];
        foreach ($varsFromCli as $var) {
            $parsedVars[] = $this->getVariableDefinition($var);
        }

        return json_encode($parsedVars);
    }

    private function storeToS3($string)
    {
        $fileName = getenv('FALLBACK_PROJECT_NAME') . '_' . getenv('PLATFORM_BRANCH')
            . 'EnvVars_' . strtoupper(date('D')) . '.json';

        $src = $this->tempDir . '/' . $fileName;
        file_put_contents($src, $string);
        if (!file_exists($src)) {
            throw new \RuntimeException('Unable to store tmp file');
        }

        $dest = $this->s3dir . '/' . $fileName;

        $cmd = "aws s3 cp {$src} {$dest} --quiet";
        if (!$this->dryRun) {
            shell_exec($cmd);
        } else {
            echo 'Command: ' . $cmd . PHP_EOL;
            echo 'File Data: ' . PHP_EOL
                . file_get_contents($src) . PHP_EOL;
        }
        unlink($src);
    }

    private function encrypt($plain): string
    {
        $supportStrong = version_compare(PHP_VERSION, '7.1.0') >= 0;
        $method = $supportStrong ? self::ENCRYPTION_METHOD_MAIN : self::ENCRYPTION_METHOD_FALLBACK;

        $encrypted = [
            'method' => $method,
            'iv' => $this->generateEncryptionInitializationVector($method),
            'tag' => ''
        ];
        // iv and tag are safely public, tag is empty on old php
        if ($supportStrong) {
            $encrypted['data'] = openssl_encrypt(
                $plain, $method, $this->secret, 0,
                $encrypted['iv'], $encrypted['tag']
            );
        } else {
            $encrypted['data'] = openssl_encrypt(
                $plain, $method, $this->secret, 0,
                $encrypted['iv']
            );
        }

        if (empty($encrypted['data'])) {
            throw new \RuntimeException('Unable to generate encrypted data');
        }

        $encrypted['iv'] = base64_encode($encrypted['iv']);
        $encrypted['tag'] = base64_encode($encrypted['tag']);
        $encrypted['data'] = base64_encode($encrypted['data']);

        return json_encode($encrypted);
    }

    private function generateEncryptionInitializationVector(string $method)
    {
        $ivLength = openssl_cipher_iv_length($method);
        $iv = null;

        // random bytes is a bit more secure, try it
        if (function_exists('random_bytes')) {
            try {
                $iv = random_bytes($ivLength);
            } catch (Exception $e) {
            }
        }
        if (!$iv) {
            $iv = openssl_random_pseudo_bytes($ivLength);
        }
        if (!$iv) {
            throw new \RuntimeException('Unable to generate Encryption Initialization Vector');
        }

        return $iv;
    }

    private function loadSecret($options)
    {
        $this->secret = $options['secret'] ?? getenv(self::ENCRYPTION_SECRET_VARNAME);
        if (!$this->secret) {
            throw new \InvalidArgumentException(
                'Invalid encryption secret. Define "' . self::ENCRYPTION_SECRET_VARNAME . '" ' .
                'or use `--secret=val` argument'
            );
        }
    }

    private function loadS3Destination($options)
    {
        $s3dir = $options['s3dir'] ?? getenv(self::S3_DIRECTORY_VARNAME);
        if (!$s3dir && $this->outputFile) {
            return; // it's okay, we'll output file content
        }
        if (!$s3dir || strpos($s3dir, 's3://') !== 0) {
            throw new \InvalidArgumentException(
                'Invalid S3 Directory "' . $s3dir . '". Define "' . self::S3_DIRECTORY_VARNAME . '" ' .
                'or use `--s3dir=s3://bucket/folder` argument.'
            );
        }
        $this->s3dir = rtrim($s3dir, '/');
    }

    private function loadTmpDir($options)
    {
        if (!empty($options['tmpdir']) && file_exists($options['tmpdir'])) {
            $this->tempDir = realpath($options['tmpdir']);
        }
        if (!$this->tempDir || !is_writable($this->tempDir)) {
            throw new \InvalidArgumentException(
                'Dir not writable: "' . $this->tempDir . '"' .
                'Make it writable or define other directory in `--tmpdir=/tmp` argument'
            );
        }
        $this->tempDir = rtrim($this->tempDir, '/');
    }

    /**
     * @param array $var
     * @return array
     */
    private function getVariableDefinition(array $var): array
    {
        if ($var[2]) {
            $value = $var[2];
        } else {
            $unprefixedName = strpos($var[0], 'env:') === 0
                ? substr($var[0], strlen('env:'))
                : $var[0];
            $value = getenv($unprefixedName);
        }

        $varDefinitionFromCli = array_map(static function ($line) {
            return explode(',', $line, 2);
        }, array_filter(
            explode("\n", shell_exec(
                "platform variable:get {$var[0]} --format=csv --no-header --level={$var[1]}"
            ))
        ));
        foreach ($varDefinitionFromCli as $k => $row) {
            if (!empty($row[1])) {
                $varDefinitionFromCli[$row[0]] = $row[1];
            }
        }

        return [
            'name' => $varDefinitionFromCli['name'],
            'level' => $varDefinitionFromCli['level'],
            'value' => $value,
            'is_inheritable' => ($varDefinitionFromCli['is_inheritable'] ?? '') === 'false' ? 'false' : 'true',
            'is_enabled' => ($varDefinitionFromCli['is_enabled'] ?? '') === 'false' ? 'false' : 'true',
            'is_json' => ($varDefinitionFromCli['is_json'] ?? '') === 'true' ? 'true' : 'false',
            'is_sensitive' => ($varDefinitionFromCli['is_sensitive'] ?? '') === 'true' ? 'true' : 'false',
            'visible_build' => ($varDefinitionFromCli['visible_build'] ?? '') === 'true' ? 'true' : 'false',
            'visible_runtime' => ($varDefinitionFromCli['visible_runtime'] ?? '') === 'true' ? 'true' : 'false'
        ];
    }
}

/* ======================================================================================== */

$options = getopt('', ['tmpdir::', 'secret::', 's3dir::', 'dry-run', 'output-file', 'help']);
if (isset($options['help'])) {
    exit(
        'Usage:' . PHP_EOL .
        'php backup_environment_variables.php --dry-run --secret=encryption-secret-content ' .
        '--s3dir="s3://bucket/folder" --tmpdir=/tmp' . PHP_EOL
    );
}

try {
    (new EnvvarBackup($options))
        ->run();
} catch (\InvalidArgumentException $exc) {
    echo 'Error: ', PHP_EOL, $exc->getMessage(), PHP_EOL;
}
