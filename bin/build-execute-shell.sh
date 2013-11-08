#!/bin/bash -xe

# For release management, add names of branches that you'd like to build packages for here.
branches="  unstable:unstable:0.1.$BUILD_NUMBER release:master:1.0.0.$BUILD_NUMBER "

repo_tmp_dir=$(mktemp --dry-run)
ssh hudson@apt.vizrt.com "mkdir $repo_tmp_dir"

for name in $branches ; do
  version=${name/*:}
  name=${name/:$version}
  suite=${name/*:}
  name=${name/:*}
  cd "$WORKSPACE" || exit
  if [ "$GIT_BRANCH_NAME" == "$name" ] ; then
    break;
  fi
done

if [ "$GIT_BRANCH_NAME" != "$name" ] ; then
  echo "Unable to build branch $GIT_BRANCH_NAME, I only support $branches"
  exit 1
fi

rm -rf target downloads work
mkdir target downloads work

version=$version-1$name

cd downloads
wget -O - -o /dev/null https://github.com/vizrt/route53cmd/archive/$name.tar.gz | tar xz
cd *-$name
# I'm now in the home directory of the package itself.
target="../../target"
work="../../work"

mv usr DEBIAN $work

sed -i -e s/VERSION/"$version"/g $work/DEBIAN/control

fakeroot dpkg-deb --build $work $target/route53cmd-$version.deb

(cd $target; fakeroot alien --keep-version --to-rpm --scripts route53cmd-$version.deb)

scp $target/*.deb hudson@apt.vizrt.com:${repo_tmp_dir}/
scp $target/*.rpm hudson@yum.vizrt.com:/var/www/yum.vizrt.com/rpm/

ssh hudson@apt.vizrt.com \
  bash /home/hudson/src/ece-scripts/usr/share/escenic/package-scripts/sign-and-add-packages-to-apt-repo \
  ${repo_tmp_dir} \
  $suite

## Update yum repository files
ssh hudson@apt.vizrt.com \
  createrepo --quiet --cachedir /home/hudson/.yum.vizrt.com --update /var/www/yum.vizrt.com/rpm/

ssh hudson@apt.vizrt.com \
    echo "echo rm -r $repo_tmp_dir/"
