---
name: php
description: Expert PHP moderne (8.2+). À invoquer pour écrire code PHP typé, Composer, PSR-12, frameworks (Laravel, Symfony), testing. Déclencheurs : "php", "composer", "laravel", "symfony", "phpstan", "phpunit".
---

# Skill : PHP moderne (8.2+)

Tu es expert PHP senior. Tu écris du code typé, testé, conforme PSR.

## Stack moderne (2026)

- **PHP 8.2+** (8.3 / 8.4 recommandés)
- **Composer** pour dépendances + autoload PSR-4
- **Style** : **PSR-12**, enforced par `php-cs-fixer`
- **Analyse statique** : **`phpstan` niveau 8** (max) ou `psalm` strict
- **Tests** : **`pest`** (moderne) ou `phpunit`
- **Frameworks** : Laravel 11+ / Symfony 7+ (conventions prioritaires sur règles génériques)

## `composer.json` minimal

```json
{
  "name": "vendor/myapp",
  "type": "project",
  "require": {
    "php": "^8.2"
  },
  "require-dev": {
    "phpunit/phpunit": "^11",
    "phpstan/phpstan": "^1.12",
    "friendsofphp/php-cs-fixer": "^3.64",
    "rector/rector": "^1.2"
  },
  "autoload": {
    "psr-4": {
      "App\\": "src/"
    }
  },
  "autoload-dev": {
    "psr-4": {
      "Tests\\": "tests/"
    }
  },
  "scripts": {
    "test": "phpunit",
    "lint": "php-cs-fixer fix --dry-run --diff",
    "fix": "php-cs-fixer fix",
    "analyse": "phpstan analyse"
  }
}
```

## PSR-12 — règles clés

- `<?php` en première ligne, **pas de balise fermante** dans les fichiers class
- `declare(strict_types=1);` immédiatement après `<?php`
- Namespace déclaré après `declare`, ligne vide, puis `use`
- Une classe par fichier
- PascalCase classes/interfaces/traits/enums
- camelCase méthodes/variables
- SCREAMING_SNAKE_CASE constantes
- Indentation 4 espaces, pas de tab
- Accolade de classe sur la ligne suivante, de méthode/fonction aussi

```php
<?php

declare(strict_types=1);

namespace App\Service;

use App\Entity\User;
use App\Repository\UserRepository;

final class UserService
{
    public function __construct(
        private readonly UserRepository $users,
    ) {
    }

    public function findActive(): array
    {
        return $this->users->findBy(['active' => true]);
    }
}
```

## Typage — obligatoire partout

```php
public function getUser(int $id): ?User
{
    return $this->repository->find($id);
}

public function search(array $criteria): iterable
{
    yield from $this->repository->search($criteria);
}
```

### Types PHP 8+ utiles
- **Union types** : `int|string`
- **Intersection types** : `Countable&Iterator`
- **Nullable** : `?int` = `int|null`
- **readonly props** (8.1+) : immutables après constructor
- **readonly classes** (8.2+) : toutes les props readonly
- **Enums** (8.1+)
  ```php
  enum Status: string
  {
      case Pending = 'pending';
      case Active  = 'active';
      case Done    = 'done';
  }
  ```
- **First-class callable syntax** : `$this->method(...)`
- **Constructor property promotion**
  ```php
  public function __construct(
      private readonly Logger $logger,
      private string $name = 'default',
  ) {}
  ```

## Patterns idiomatiques

### Value Objects
```php
final readonly class Email
{
    public function __construct(public string $value)
    {
        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
            throw new \InvalidArgumentException("Invalid email: $value");
        }
    }

    public function __toString(): string
    {
        return $this->value;
    }
}
```

### Exceptions typées
```php
class UserNotFoundException extends \RuntimeException {}

throw new UserNotFoundException("User {$id} not found");
```

### Named arguments (8.0+)
```php
$user = new User(
    name: 'Alice',
    email: 'alice@example.com',
    role: Role::Admin,
);
```

### Match expression
```php
$label = match ($status) {
    Status::Pending => 'En attente',
    Status::Active  => 'Actif',
    Status::Done    => 'Terminé',
};
```

## PHPStan — niveau strict

`phpstan.neon` :
```yaml
parameters:
  level: 8
  paths:
    - src
  treatPhpDocTypesAsCertain: true
  reportUnmatchedIgnoredErrors: true
  checkGenericClassInNonGenericObjectType: true
```

**Règle** : 0 erreur PHPStan au niveau 8 avant merge.

## Tests — Pest (recommandé)

```php
// tests/Feature/UserTest.php
use App\Service\UserService;

it('returns active users', function () {
    $service = new UserService($this->repository);
    $users = $service->findActive();
    expect($users)->toHaveCount(3);
});

it('throws when user not found', function () {
    expect(fn() => $this->service->getUser(99999))
        ->toThrow(UserNotFoundException::class);
});
```

### PHPUnit classique
```php
final class UserServiceTest extends TestCase
{
    private UserService $service;

    protected function setUp(): void
    {
        $this->service = new UserService(...);
    }

    public function test_returns_active_users(): void
    {
        $users = $this->service->findActive();
        self::assertCount(3, $users);
    }
}
```

## Sécurité

- **Requêtes préparées** systématiques (PDO / ORM), **jamais** de concat SQL
- **Escape** contextuel (HTML → `htmlspecialchars`, URL → `urlencode`, JS → json_encode + CSP)
- **CSRF tokens** sur tous les POST
- **Password** : `password_hash(PASSWORD_ARGON2ID)`, `password_verify`
- **Sessions** : `secure`, `httponly`, `samesite`, régénération post-auth
- **Fichiers uploadés** : validation MIME réelle + extension + taille, stockage hors webroot
- **Pas de `@` suppresseur** — gérer les erreurs proprement
- **Jamais** `$_GET/$_POST` direct → validation systématique (filters, Symfony Validator, Laravel Form Requests)

## Frameworks — règles d'or

### Laravel
- **Eloquent** : `$fillable` ou `$guarded`, jamais les deux ; prévoir `$hidden` pour les cols sensibles
- **Migrations** : toujours réversibles
- **Queues** pour jobs > 500 ms
- **Events** : attention à la sync vs async
- **Config** : jamais `env()` hors fichier de config → cache casse sinon
- **Pas de logique dans les blades**, tout dans controllers/services

### Symfony
- **Services** en autowire/autoconfigure
- **DTOs** typés pour input/output d'API
- **Messenger** pour async
- **Doctrine** : `Repository` pour queries métier, pas de `EntityManager` au milieu d'un controller
- **Voters** pour authz, pas de `if ($user->isAdmin())` inline
- **Profiler** en dev pour détecter N+1

## Red flags

- Pas de `declare(strict_types=1)`
- `mixed` ou pas de type du tout
- `@` suppresseur d'erreur
- SQL concaténé
- `eval()` ou `create_function()`
- Variables globales
- Méthodes statiques pour logique métier (untestable)
- `die`/`exit` ailleurs que dans un bootstrap
- Pas de composer.lock versionné
- PHP < 8.2 (EOL / plus de security patches pour certaines versions)
- Classes de 1000+ lignes (God object)
- `new` dans un service (couplage fort, pas testable) — utiliser DI

## Commandes cheatsheet

```bash
composer install
composer update --prefer-dist
composer require vendor/package
composer require --dev vendor/package
composer show -D                  # top-level deps
composer audit                    # scan CVE

vendor/bin/phpstan analyse
vendor/bin/php-cs-fixer fix
vendor/bin/phpunit
vendor/bin/pest

# Laravel
php artisan migrate
php artisan make:controller UserController
php artisan test

# Symfony
bin/console cache:clear
bin/console make:entity
bin/console doctrine:migrations:migrate
```

## Learnings

<!-- Enrichi via /skill-enrich php -->
