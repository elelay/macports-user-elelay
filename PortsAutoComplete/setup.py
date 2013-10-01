from setuptools import find_packages, setup

version='0.1.0'

setup(name='portsautocomplete',
      version=version,
      description="complete the known ports",
      author='Eric Le Lay',
      author_email='elelay@macports.org',
      url='http://trac.macports.org/wiki/elelay',
      keywords='trac plugin',
      license="GPLv3",
      packages=find_packages(exclude=['ez_setup', 'examples', 'tests*']),      
      include_package_data=True,
      package_data={'portsautocomplete': ['htdocs/css/*', 'htdocs/js/*']},
      zip_safe=False,
      entry_points = """
      [trac.plugins]
      portsautocomplete = portsautocomplete
      """,
      )

